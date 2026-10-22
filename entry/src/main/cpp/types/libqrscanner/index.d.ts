/** Local, offline QR decoder. Work runs outside the ArkUI thread. */
export const decode: (data: Uint8Array, width: number, height: number,
  rowStride: number, pixelStride: number, rgba: boolean) => Promise<string[]>;
