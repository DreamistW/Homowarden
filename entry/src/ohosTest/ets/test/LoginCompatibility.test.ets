import { describe, it } from '@ohos/hypium';
import { runLoginCompatibilityChecks } from './LoginCompatibilityChecks';
import { runLoginAuditChecks } from './LoginAuditChecks';

export default function loginCompatibilityTest(): void {
  describe('LoginCompatibility', () => {
    it('remainingAuditRegressions', 0, () => {
      runLoginAuditChecks();
    });
    it('nativeKdfAndProtocolCompatibility', 0, async () => {
      await runLoginCompatibilityChecks();
    });
  });
}
