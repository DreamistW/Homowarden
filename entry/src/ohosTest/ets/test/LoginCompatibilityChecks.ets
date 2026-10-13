import { KdfUtil } from '../../../main/ets/utils/KdfUtil';
import { CryptoUtil } from '../../../main/ets/utils/CryptoUtil';
import { util } from '@kit.ArkTS';
import { LoginErrorUtil } from '../../../main/ets/utils/LoginErrorUtil';
import { AccessTokenResponse } from '../../../main/ets/model/AccessToken';
import { KdfParameters } from '../../../main/ets/model/Prelogin';
import { DECRYPTION_UNSUPPORTED, LoginResponseUtil,
  PASSWORD_RESET_REQUIRED } from '../../../main/ets/utils/LoginResponseUtil';
import { LogSanitizer } from '../../../main/ets/utils/LogSanitizer';

const WRAPPED_USER_KEY = '2.AAECAwQFBgcICQoLDA0ODw==|' +
  'JDP4Z6UHPanJhGKqM55qGFcQx4ULxZMLlZrGtcyLc76zf8roJVXuN0wFS69Sroy9MMIhtvR/U+e3ZITG3BgouFzX5zepjwB3LY5Wkz2cBEw=|' +
  '+sQTo3a+C8W+tQaenCP5IeOTPWj1/vUBt1efrdhnbDw=';
const PLAIN_USER_KEY = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+Pw==';

function check(condition: boolean, name: string): void {
  if (!condition) {
    throw new Error(`Login compatibility check failed: ${name}`);
  }
}

function rejectsInvalidKdf(): void {
  let rejected = false;
  try {
    KdfUtil.normalize({ kdfSettings: { kdfType: 1, iterations: 6, memory: 0, parallelism: 4 } }, 'test@example.com');
  } catch (_) {
    rejected = true;
  }
  check(rejected, 'invalid Argon2id parameters');
}

function rejectsToken(response: AccessTokenResponse, params: KdfParameters, expected: string): void {
  let rejected = false;
  try {
    LoginResponseUtil.normalize(response, params, 'test@bitwarden.com');
  } catch (error) {
    rejected = (error as Error).message === expected;
  }
  check(rejected, expected);
}

/** 公开测试输入；不读取账号资产，也不访问服务器。 */
export async function runLoginCompatibilityChecks(): Promise<void> {
  const legacy = KdfUtil.normalize({ kdf: 0, kdfIterations: 100000, kdfMemory: null }, ' TEST@bitwarden.com ');
  check(legacy.salt === 'test@bitwarden.com', 'legacy email salt');
  const modern = KdfUtil.normalize({
    kdf: 0,
    kdfIterations: 1,
    kdfSettings: { kdfType: 1, iterations: 4, memory: 32, parallelism: 2 },
    salt: ' TEST_SALT '
  }, 'different@example.com');
  check(modern.kdf === 1 && modern.salt === 'test_salt', 'modern fields take precedence');
  const restored = KdfUtil.normalize(JSON.parse(JSON.stringify(modern)), 'different@example.com');
  check(restored.salt === modern.salt && restored.kdfIterations === 4, 'stored salt survives restart');
  rejectsInvalidKdf();
  check(LoginErrorUtil.isNewDeviceVerificationRequired({ error: 'device_error',
    ErrorModel: { Message: 'new device verification required' } }), 'new device challenge');
  check(LoginErrorUtil.isNewDeviceVerificationRequired({ error: 'device_error',
    error_description: 'New Device Verification Required.' }), 'challenge description fallback');
  check(!LoginErrorUtil.isNewDeviceVerificationRequired({ error: 'device_error',
    error_description: 'Invalid New Device OTP' }), 'invalid OTP is not a fresh challenge');
  check(!LoginErrorUtil.isNewDeviceVerificationRequired({ error: 'device_error',
    error_description: 'No device information provided' }), 'other device error is not a challenge');
  check(LoginErrorUtil.isInvalidVerificationCode({ error: 'device_error',
    errorModel: { message: 'invalid new device otp' } }), 'invalid OTP retry');
  check(LoginErrorUtil.isInvalidCredentials({ ErrorModel: {
    Message: 'Username or password is incorrect. Try again.' } }), 'credential message compatibility');

  // 官方 SDK master_key.rs 的认证值向量，覆盖设备原生 KDF 和 HMAC。
  const base64 = new util.Base64Helper();
  const pbkdf2Key = await CryptoUtil.deriveMasterKey('asdfasdf', legacy);
  const pbkdf2Hash = await CryptoUtil.deriveKeyPBKDF2SingleIteration(base64.decodeSync(pbkdf2Key), 'asdfasdf');
  check(pbkdf2Hash === 'wmyadRMyBZOH7P/a/ucTCbSghKgdzDpPqUnu/DAVtSw=', 'official PBKDF2 vector');
  const argonKey = await CryptoUtil.deriveMasterKey('asdfasdf', modern);
  const argonHash = await CryptoUtil.deriveKeyPBKDF2SingleIteration(base64.decodeSync(argonKey), 'asdfasdf');
  check(argonHash === 'PR6UjYmjmppTYcdyTiNbAhPJuQQOmynKbdEl1oyi/iQ=', 'official Argon2id vector');

  const token: AccessTokenResponse = {
    access_token: 'public-test-token', refresh_token: 'public-test-refresh', expires_in: 3600,
    Key: WRAPPED_USER_KEY, PrivateKey: '2.legacy|private|key'
  };
  const legacyMaterial = LoginResponseUtil.normalize(token, legacy, 'test@bitwarden.com');
  check(legacyMaterial.source === 'legacy', 'legacy token response');
  token.UserDecryptionOptions = { HasMasterPassword: true };
  check(LoginResponseUtil.normalize(token, legacy, 'test@bitwarden.com').source === 'legacy',
    'older decryption options retain legacy key compatibility');
  token.UserDecryptionOptions = {
    MasterPasswordUnlock: {
      Kdf: { KdfType: 0, Iterations: 100000 },
      Salt: 'TEST@bitwarden.com', MasterKeyEncryptedUserKey: WRAPPED_USER_KEY
    }
  };
  token.AccountKeys = { publicKeyEncryptionKeyPair: { wrappedPrivateKey: '2.modern|private|key' } };
  token.Key = undefined;
  token.PrivateKey = undefined;
  const modernMaterial = LoginResponseUtil.normalize(token, modern, 'different@example.com');
  check(modernMaterial.source === 'modern' && modernMaterial.encryptedPrivateKey === '2.modern|private|key',
    'modern-only token keys');
  check(modernMaterial.params.salt === 'test@bitwarden.com' &&
    !LoginResponseUtil.sameKdf(modernMaterial.params, modern), 'separate authentication and unlock parameters');
  const userKey = await CryptoUtil.decryptUserKey(modernMaterial.encryptedUserKey, pbkdf2Key);
  check(userKey === PLAIN_USER_KEY, 'native HKDF and authenticated user key decryption');
  let corruptRejected = false;
  try {
    await CryptoUtil.decryptUserKey(WRAPPED_USER_KEY.replace('+sQTo3', 'AsQTo3'), pbkdf2Key);
  } catch (_) {
    corruptRejected = true;
  }
  check(corruptRejected, 'corrupt user key rejected before saving');
  token.ForcePasswordReset = true;
  rejectsToken(token, legacy, PASSWORD_RESET_REQUIRED);
  token.ForcePasswordReset = false;
  token.UserDecryptionOptions = { HasMasterPassword: false };
  token.Key = WRAPPED_USER_KEY;
  rejectsToken(token, legacy, DECRYPTION_UNSUPPORTED);
  token.UserDecryptionOptions = undefined;
  token.Key = '7.unsupported-format';
  rejectsToken(token, legacy, DECRYPTION_UNSUPPORTED);
  const sanitized = LogSanitizer.sanitize('{"salt":"short_salt","wrappedPrivateKey":"short_key",' +
    '"MasterKeyEncryptedUserKey":"short_user_key","kdf":1}');
  check(!sanitized.includes('short_salt') && !sanitized.includes('short_key') &&
    !sanitized.includes('short_user_key') && sanitized.includes('"kdf":1'), 'new fields are redacted');
}
