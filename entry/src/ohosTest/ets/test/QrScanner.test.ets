import { describe, it, expect } from '@ohos/hypium';
import { decode } from 'libqrscanner.so';
import { QR_ROWS, QR_PAYLOAD, SECOND_QR_ROWS, SECOND_QR_PAYLOAD } from './QrFixture';

function fixture(rgba: boolean, rotate: boolean): Uint8Array {
  const side = QR_ROWS.length * 4;
  const channels = rgba ? 4 : 1;
  const stride = side * channels + 8;
  const data = new Uint8Array(stride * side);
  data.fill(255);
  for (let y = 0; y < side; y++) {
    for (let x = 0; x < side; x++) {
      const sourceX = rotate ? y : x;
      const sourceY = rotate ? side - 1 - x : y;
      const value = QR_ROWS[Math.floor(sourceY / 4)][Math.floor(sourceX / 4)] === '1' ? 0 : 255;
      const offset = y * stride + x * channels;
      data[offset] = value;
      if (rgba) { data[offset + 1] = value; data[offset + 2] = value; }
    }
  }
  return data;
}

export default function qrScannerTest(): void {
  describe('QrScannerNative', () => {
    it('decodesSyntheticTotpWithPaddedRows', 0, async () => {
      const side = QR_ROWS.length * 4;
      const results = await decode(fixture(false, false), side, side, side + 8, 1, false);
      expect(results.includes(QR_PAYLOAD)).assertTrue();
    });
    it('decodesRotatedRgbaPixels', 0, async () => {
      const side = QR_ROWS.length * 4;
      const results = await decode(fixture(true, true), side, side, side * 4 + 8, 4, true);
      expect(results.includes(QR_PAYLOAD)).assertTrue();
    });
    it('returnsAllCodesInOneImage', 0, async () => {
      const side = QR_ROWS.length * 4;
      const data = new Uint8Array(side * 2 * side);
      const source = fixture(false, false);
      for (let y = 0; y < side; y++) {
        const row = source.subarray(y * (side + 8), y * (side + 8) + side);
        data.set(row, y * side * 2);
        for (let x = 0; x < side; x++) {
          data[y * side * 2 + side + x] =
            SECOND_QR_ROWS[Math.floor(y / 4)][Math.floor(x / 4)] === '1' ? 0 : 255;
        }
      }
      const results = await decode(data, side * 2, side, side * 2, 1, false);
      expect(results.length).assertEqual(2);
      expect(results.includes(QR_PAYLOAD)).assertTrue();
      expect(results.includes(SECOND_QR_PAYLOAD)).assertTrue();
    });
    it('returnsNoResultForBlankImage', 0, async () => {
      const data = new Uint8Array(64 * 64);
      data.fill(255);
      expect((await decode(data, 64, 64, 64, 1, false)).length).assertEqual(0);
    });
    it('rejectsTruncatedAndOversizedInput', 0, async () => {
      let rejected = 0;
      try { await decode(new Uint8Array(1), 100, 100, 100, 1, false); } catch (_) { rejected++; }
      try { await decode(new Uint8Array(1), 100000, 100000, 100000, 1, false); } catch (_) { rejected++; }
      expect(rejected).assertEqual(2);
    });
  });
}
