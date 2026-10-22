# ZBar from XCodeScanner 682d3f24; LGPL-2.1-or-later. See README.md.
add_library(zbar SHARED
  zbar/img_scanner.c
  zbar/decoder.c
  zbar/image.c
  zbar/symbol.c
  zbar/convert.c
  zbar/config.c
  zbar/scanner.c
  zbar/error.c
  zbar/refcnt.c
  zbar/video.c
  zbar/video/null.c
  zbar/decoder/code128.c
  zbar/decoder/code39.c
  zbar/decoder/code93.c
  zbar/decoder/codabar.c
  zbar/decoder/databar.c
  zbar/decoder/ean.c
  zbar/decoder/i25.c
  zbar/decoder/qr_finder.c
  zbar/qrcode/bch15_5.c
  zbar/qrcode/binarize.c
  zbar/qrcode/isaac.c
  zbar/qrcode/qrdec.c
  zbar/qrcode/qrdectxt.c
  zbar/qrcode/rs.c
  zbar/qrcode/util.c
)
target_include_directories(zbar PUBLIC include PRIVATE . zbar)
set_target_properties(zbar PROPERTIES C_STANDARD 99 C_EXTENSIONS ON)
target_link_libraries(zbar PRIVATE m)
target_link_options(zbar PRIVATE -Wl,--no-undefined)
