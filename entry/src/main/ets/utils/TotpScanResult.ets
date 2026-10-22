import { TOTPUtil } from './TOTPUtil';

/** A generic QR code must never be treated as a manually entered TOTP secret. */
export class TotpScanResult {
  static findUri(values: string[]): string | undefined {
    for (const value of values) {
      const uri = value.trim();
      if (!uri.startsWith('otpauth://totp/')) {
        continue;
      }
      if (TOTPUtil.isValidSecret(TOTPUtil.parseOtpAuthUrl(uri).secret)) {
        return uri;
      }
    }
    return undefined;
  }
}
