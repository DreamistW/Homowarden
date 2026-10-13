import abilityTest from './Ability.test';
import loginCompatibilityTest from './LoginCompatibility.test';
import credentialStorageTest from './CredentialStorage.test';

export default function testsuite() {
  abilityTest();
  loginCompatibilityTest();
  credentialStorageTest();
}
