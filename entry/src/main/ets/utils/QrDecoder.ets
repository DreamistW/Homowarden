import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { decode } from 'libqrscanner.so';

/** Offline decoder shared by camera frames and the system image picker. Never logs payloads. */
export class QrDecoder {
  static async gray(bytes: Uint8Array, width: number, height: number,
    rowStride: number, pixelStride: number = 1): Promise<string[]> {
    return decode(bytes, width, height, rowStride, pixelStride, false);
  }

  /** undefined means the picker was cancelled; [] means no QR code was found. */
  static async pickImage(context: common.UIAbilityContext): Promise<string[] | undefined> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const selection = await new photoAccessHelper.PhotoViewPicker().select(options);
    if (selection.photoUris.length === 0) {
      return undefined;
    }
    return QrDecoder.decodeUri(selection.photoUris[0]);
  }

  static async decodeUri(uri: string): Promise<string[]> {
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
    let source: image.ImageSource | undefined;
    let pixels: image.PixelMap | undefined;
    let bytes: Uint8Array | undefined;
    try {
      source = image.createImageSource(file.fd);
      const info = await source.getImageInfo();
      const width = info.size.width;
      const height = info.size.height;
      if (width < 1 || height < 1 || width * height > 100000000) {
        throw new Error('qr_image_size');
      }
      const scale = Math.min(1, 1920 / Math.max(width, height));
      pixels = await source.createPixelMap({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredSize: { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) }
      });
      const decoded = await pixels.getImageInfo();
      const count = pixels.getPixelBytesNumber();
      if (count > 16 * 1024 * 1024) {
        throw new Error('qr_image_size');
      }
      bytes = new Uint8Array(count);
      await pixels.readPixelsToBuffer(bytes.buffer);
      return await decode(bytes, decoded.size.width, decoded.size.height, pixels.getBytesNumberPerRow(), 4, true);
    } finally {
      bytes?.fill(0);
      try {
        await pixels?.release();
      } finally {
        try {
          await source?.release();
        } finally {
          await fileIo.close(file);
        }
      }
    }
  }
}
