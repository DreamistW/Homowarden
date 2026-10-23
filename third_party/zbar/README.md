# ZBar decoder used by Homowarden OpenHarmony

Source: <https://github.com/Simon-Leeeeeeeee/XCodeScanner>

Pinned revision: `682d3f24e3f4888bb898c3e197d84cdf5b098a66` (XCodeScanner 1.1.10).
The decoder identifies itself as ZBar 0.10.

`config.h`, `Android.mk`, `include/`, and `zbar/` were copied from
`zbar/src/main/jni/` at that revision. Original copyright and license notices
are preserved. `CMakeLists.txt` is the OpenHarmony build integration added by
Homowarden; the upstream decoder source has not been modified.

The upstream repository's Apache-2.0 license does not replace the ZBar files'
LGPL-2.1-or-later notices. See `LICENSE-LGPL-2.1.txt` and each file header.
The GNU libiconv source, Android JNI bridge, Java code and Android binaries
are not included. Character conversion uses OpenHarmony libc's iconv.

Build from the repository root with the OpenHarmony API 23 SDK configured:

```powershell
# Configure JAVA_HOME for your JDK installation.
# Configure OHOS_BASE_SDK_HOME for your OpenHarmony SDK installation.
devecocli.cmd build --modules entry@default
```

The entry module's external native build compiles this CMake target for
`arm64-v8a` and `x86_64`. It creates a separate `libzbar.so`, dynamically linked
by `libqrscanner.so`. Retaining that separate shared-library boundary allows
rebuilding/relinking the decoder without changing the ArkTS interface.
The corresponding source and build configuration are included in this tree.

When distributing binaries, include the notices and license, provide the
corresponding source and build instructions for the exact distributed version,
and satisfy the applicable LGPL library replacement/relinking requirements.
An app package must be rebuilt and signed for its intended device after
replacing a native library. The packaged notices are also in
`entry/src/main/resources/rawfile/zbar/`.

The native wrapper accepts bounded grayscale/RGBA pixel buffers and enables
QR codes only. It serializes native work because the upstream configuration
does not enable thread-safe reference counting. It does not use a network,
system scan service, Android runtime, or HarmonyOS ScanKit.
