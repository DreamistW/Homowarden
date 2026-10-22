import abilityTest from './Ability.test';
import loginCompatibilityTest from './LoginCompatibility.test';
import credentialStorageTest from './CredentialStorage.test';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import cipherCrudTest from './CipherCrud.test';
import qrScannerTest from './QrScanner.test';

export default function testsuite() {
  if (abilityDelegatorRegistry.getArguments().parameters['-s liveCrud'] === 'true') {
    cipherCrudTest();
    return;
  }
  abilityTest();
  qrScannerTest();
  loginCompatibilityTest();
  credentialStorageTest();
}
