import { describe, it, expect } from '@ohos/hypium';
import { LogSanitizer } from '../main/ets/utils/LogSanitizer';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    it('assertContain', 0, () => {
      let a = 'abc';
      let b = 'b';
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('redactsSensitiveDiagnosticValues', 0, () => {
      const source = 'email=user@example.com password=secret Bearer abcdefghijklmnopqrstuvwxyz123456 ' +
        'id=123e4567-e89b-42d3-a456-426614174000 url=https://vault.example.com/api ' +
        'otp=otpauth://totp/Example?secret=JBSWY3DPEHPK3PXP path=/data/storage/el2/base/files/db';
      const sanitized = LogSanitizer.sanitize(source);

      expect(sanitized.includes('user@example.com')).assertFalse();
      expect(sanitized.includes('vault.example.com')).assertFalse();
      expect(sanitized.includes('123e4567-e89b-42d3-a456-426614174000')).assertFalse();
      expect(sanitized.includes('JBSWY3DPEHPK3PXP')).assertFalse();
      expect(sanitized.includes('[REDACTED_EMAIL]')).assertTrue();
    });

    it('keepsUsefulDiagnosticContext', 0, () => {
      const source = '[HTTP] Response Error: status=401, message=Request failed';
      expect(LogSanitizer.sanitize(source)).assertEqual(source);
    });

    it('isIdempotent', 0, () => {
      const once = LogSanitizer.sanitize('contact=user@example.com token=secret-value');
      expect(LogSanitizer.sanitize(once)).assertEqual(once);
    });
  });
}
