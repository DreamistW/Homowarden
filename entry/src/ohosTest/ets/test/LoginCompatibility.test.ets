import { describe, it } from '@ohos/hypium';
import { runLoginCompatibilityChecks } from './LoginCompatibilityChecks';

export default function loginCompatibilityTest(): void {
  describe('LoginCompatibility', () => {
    it('nativeKdfAndProtocolCompatibility', 0, async () => {
      await runLoginCompatibilityChecks();
    });
  });
}
