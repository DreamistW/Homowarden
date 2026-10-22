#include <napi/native_api.h>
#include <zbar.h>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace {
using namespace zbar;
constexpr uint32_t MAX_SIDE = 4096;
constexpr uint64_t MAX_PIXELS = 4 * 1024 * 1024;
std::atomic_bool busy {false}; // The old ZBar refcounts are not atomic.

void Erase(std::vector<uint8_t>& bytes)
{
    volatile uint8_t* p = bytes.data();
    for (size_t i = 0; i < bytes.size(); ++i) p[i] = 0;
}

struct Work {
    napi_async_work task = nullptr;
    napi_deferred deferred = nullptr;
    std::vector<uint8_t> input;
    uint32_t width = 0, height = 0, rowStride = 0, pixelStride = 0;
    bool rgba = false;
    bool failed = false;
    std::vector<std::string> results;
    ~Work() { Erase(input); }
};

bool Dimension(napi_env env, napi_value value, uint32_t& out)
{
    double number = 0;
    if (napi_get_value_double(env, value, &number) != napi_ok || !std::isfinite(number) ||
        number < 1 || number > UINT32_MAX || std::floor(number) != number) return false;
    out = static_cast<uint32_t>(number);
    return true;
}

void Execute(napi_env, void* data)
{
    auto& work = *static_cast<Work*>(data);
    try {
        std::vector<uint8_t> gray(static_cast<size_t>(work.width) * work.height);
        for (uint32_t y = 0; y < work.height; ++y) {
            for (uint32_t x = 0; x < work.width; ++x) {
                const auto* p = work.input.data() + static_cast<size_t>(y) * work.rowStride +
                    static_cast<size_t>(x) * work.pixelStride;
                gray[static_cast<size_t>(y) * work.width + x] = work.rgba ?
                    static_cast<uint8_t>((77u * p[0] + 150u * p[1] + 29u * p[2]) >> 8) : p[0];
            }
        }
        std::unique_ptr<zbar_image_scanner_t, decltype(&zbar_image_scanner_destroy)>
            scanner(zbar_image_scanner_create(), zbar_image_scanner_destroy);
        std::unique_ptr<zbar_image_t, decltype(&zbar_image_destroy)> image(zbar_image_create(), zbar_image_destroy);
        if (!scanner || !image) {
            Erase(gray);
            work.failed = true;
            return;
        }
        zbar_image_scanner_set_config(scanner.get(), ZBAR_NONE, ZBAR_CFG_ENABLE, 0);
        zbar_image_scanner_set_config(scanner.get(), ZBAR_QRCODE, ZBAR_CFG_ENABLE, 1);
        zbar_image_scanner_enable_cache(scanner.get(), 0);
        zbar_image_set_format(image.get(), zbar_fourcc('Y', '8', '0', '0'));
        zbar_image_set_size(image.get(), work.width, work.height);
        zbar_image_set_data(image.get(), gray.data(), gray.size(), nullptr);
        if (zbar_scan_image(scanner.get(), image.get()) < 0) work.failed = true;
        for (auto* symbol = zbar_image_first_symbol(image.get()); symbol && work.results.size() < 32;
             symbol = zbar_symbol_next(symbol)) {
            const auto length = zbar_symbol_get_data_length(symbol);
            if (zbar_symbol_get_type(symbol) == ZBAR_QRCODE && length > 0 && length <= 8192) {
                work.results.emplace_back(zbar_symbol_get_data(symbol), length);
            }
        }
        // Drop the borrowed pixel pointer before clearing its storage.
        zbar_image_set_data(image.get(), nullptr, 0, nullptr);
        Erase(gray);
    } catch (...) {
        work.failed = true;
    }
    Erase(work.input);
}

void Complete(napi_env env, napi_status status, void* data)
{
    std::unique_ptr<Work> work(static_cast<Work*>(data));
    busy.store(false);
    if (env) {
        napi_value value;
        if (status != napi_ok || work->failed) {
            napi_value message;
            napi_create_string_utf8(env, "QR decoding failed", NAPI_AUTO_LENGTH, &message);
            napi_create_error(env, nullptr, message, &value);
            napi_reject_deferred(env, work->deferred, value);
        } else {
            napi_create_array_with_length(env, work->results.size(), &value);
            for (size_t i = 0; i < work->results.size(); ++i) {
                napi_value text;
                napi_create_string_utf8(env, work->results[i].data(), work->results[i].size(), &text);
                napi_set_element(env, value, i, text);
            }
            napi_resolve_deferred(env, work->deferred, value);
        }
        napi_delete_async_work(env, work->task);
    }
}

napi_value Decode(napi_env env, napi_callback_info info)
{
    size_t argc = 6;
    napi_value argv[6];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    auto work = std::make_unique<Work>();
    napi_typedarray_type type;
    size_t length = 0, offset = 0;
    void* bytes = nullptr;
    napi_value buffer;
    if (argc != 6 || napi_get_typedarray_info(env, argv[0], &type, &length, &bytes, &buffer, &offset) != napi_ok ||
        type != napi_uint8_array || !Dimension(env, argv[1], work->width) ||
        !Dimension(env, argv[2], work->height) || !Dimension(env, argv[3], work->rowStride) ||
        !Dimension(env, argv[4], work->pixelStride) || napi_get_value_bool(env, argv[5], &work->rgba) != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid QR image arguments");
        return nullptr;
    }
    const uint64_t channels = work->rgba ? 4 : 1;
    const uint64_t rowBytes = static_cast<uint64_t>(work->width - 1) * work->pixelStride + channels;
    const uint64_t required = static_cast<uint64_t>(work->height - 1) * work->rowStride + rowBytes;
    if (work->width > MAX_SIDE || work->height > MAX_SIDE ||
        static_cast<uint64_t>(work->width) * work->height > MAX_PIXELS ||
        work->pixelStride < channels || work->pixelStride > 4 || work->rowStride < rowBytes ||
        required > length || required > MAX_PIXELS * 4 || !bytes) {
        napi_throw_range_error(env, nullptr, "QR image exceeds bounds");
        return nullptr;
    }
    if (busy.exchange(true)) {
        napi_throw_error(env, "QR_BUSY", "QR decoder is busy");
        return nullptr;
    }
    try {
        work->input.assign(static_cast<uint8_t*>(bytes), static_cast<uint8_t*>(bytes) + required);
    } catch (...) {
        busy.store(false);
        napi_throw_error(env, nullptr, "QR image allocation failed");
        return nullptr;
    }
    napi_value promise, name;
    napi_create_string_utf8(env, "DecodeQR", NAPI_AUTO_LENGTH, &name);
    if (napi_create_promise(env, &work->deferred, &promise) != napi_ok ||
        napi_create_async_work(env, nullptr, name, Execute, Complete, work.get(), &work->task) != napi_ok ||
        napi_queue_async_work(env, work->task) != napi_ok) {
        if (work->task) napi_delete_async_work(env, work->task);
        busy.store(false);
        napi_throw_error(env, nullptr, "Cannot schedule QR decoding");
        return nullptr;
    }
    work.release();
    return promise;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor property = {"decode", nullptr, Decode, nullptr, nullptr, nullptr, napi_default, nullptr};
    napi_define_properties(env, exports, 1, &property);
    return exports;
}
napi_module module = {1, 0, nullptr, Init, "qrscanner", nullptr, {nullptr}};
}
extern "C" __attribute__((constructor)) void RegisterQrScanner() { napi_module_register(&module); }
