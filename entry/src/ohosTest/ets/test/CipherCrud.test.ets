import { describe, expect, it } from '@ohos/hypium';
import { runCipherCrudChecks } from './CipherCrudChecks';

/** Real network/storage tests, enabled only by the explicit liveCrud runner flag. */
export default function cipherCrudTest(): void {
  describe('CipherCrudLive', () => {
    it('allTypesAllEditableFieldsAndLifecycle', 0, async () => {
      expect(await runCipherCrudChecks()).assertEqual(0);
    });
  });
}
