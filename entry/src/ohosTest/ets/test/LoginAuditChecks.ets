import { AccessTokenResponse } from '../../../main/ets/model/AccessToken';
import { LoginErrorResponseData, LoginRequestError } from '../../../main/ets/model/LoginError';
import { LoginErrorUtil } from '../../../main/ets/utils/LoginErrorUtil';
import { LoginResponseUtil, DECRYPTION_UNSUPPORTED } from '../../../main/ets/utils/LoginResponseUtil';
import { AuthProtocolUtil, AUTH_TIMEOUT_MS } from '../../../main/ets/utils/AuthProtocolUtil';
import { AppTextKey } from '../../../main/ets/localization/AppText';
import { LogSanitizer } from '../../../main/ets/utils/LogSanitizer';
import { createHttpClient } from '../../../main/ets/network/HttpClient';
import { KdfParameters } from '../../../main/ets/model/Prelogin';

function check(value: boolean, name: string): void {
  if (!value) {
    throw new Error(`Login audit regression: ${name}`);
  }
}

function classify(message: string, expected: AppTextKey, status: number = 400): void {
  const error: LoginRequestError = { response: { status: status, data: { error_description: message } } };
  check(LoginErrorUtil.classify(error) === expected, `error classification ${expected}`);
}

/** 公开输入，无真实账号/服务器访问。实际 MAC/AES/Argon2 向量由同套件另一测试覆盖。 */
export function runLoginAuditChecks(): void {
  check(AuthProtocolUtil.origin('https://host:8443/vault/path?x=1') === 'https://host:8443', 'subpath origin');
  check(AuthProtocolUtil.origin('https://[2001:db8::1]:8443/vault') === 'https://[2001:db8::1]:8443', 'IPv6 origin');
  const client = createHttpClient('https://example.invalid/identity', { timeout: AUTH_TIMEOUT_MS });
  check(client.defaults.timeout === 30000, 'authentication timeout applies');
  check(createHttpClient('https://example.invalid').defaults.timeout === 10000, 'default timeout preserved');

  const providers: LoginErrorResponseData = { TwoFactorProviders2: {}, TwoFactorProviders: ['0', '1'] };
  check(LoginErrorUtil.isTwoFactorRequired(providers), 'legacy providers enter verification');
  check(LoginErrorUtil.providers(providers).join(',') === '0,1', 'empty dictionary fallback');
  check(LoginErrorUtil.isInvalidVerificationCode({ error_description: 'Two-step token is invalid. Try again.' }),
    'official invalid TOTP message');
  classify('Two-step token is invalid. Try again.', AppTextKey.CODE_INVALID);
  classify('Please verify your email before trying again', AppTextKey.EMAIL_UNVERIFIED);
  classify('This user has been disabled', AppTextKey.ACCOUNT_DISABLED);
  classify('SSO sign-in is required', AppTextKey.SSO_REQUIRED);
  classify('Legacy account requires migration', AppTextKey.ACCOUNT_MIGRATION_REQUIRED);
  classify('invalid_client_version', AppTextKey.CLIENT_VERSION_UNSUPPORTED);
  classify('', AppTextKey.RATE_LIMITED, 429);
  classify('<html>Cloudflare challenge</html>', AppTextKey.ACCESS_RESTRICTED, 403);
  check(LoginErrorUtil.classify({ message: 'Operation timeout' }) === AppTextKey.TIMEOUT_ERROR, 'timeout');
  check(LoginErrorUtil.classify({ message: 'network unavailable' }) === AppTextKey.NETWORK_ERROR, 'network');

  const encrypted = '2.iv|cipher|mac';
  const token: AccessTokenResponse = {
    access_token: 'test-access', refresh_token: 'test-refresh', expires_in: 3600,
    Key: '2.legacy|legacy|legacy',
    userDecryptionOptions: { masterPasswordUnlock: {
      kdf: { kdfType: 0, iterations: 100000 }, salt: ' TEST@EXAMPLE.COM ',
      masterKeyWrappedUserKey: encrypted
    } },
    accountKeys: { publicKeyEncryptionKeyPair: { wrappedPrivateKey: '2.new|private|key' } }
  };
  const params: KdfParameters = {
    kdf: 0, kdfIterations: 100000, kdfMemory: 0, kdfParallelism: 0, salt: 'test@example.com'
  };
  const modern = LoginResponseUtil.normalize(token, params, 'test@example.com');
  check(modern.encryptedUserKey === encrypted && modern.source === 'modern', 'camelCase wrapped key');
  check(modern.encryptedPrivateKey === '2.new|private|key', 'camelCase account keys');
  token.userDecryptionOptions = { MasterPasswordUnlock: {
    Kdf: { KdfType: 0, Iterations: 100000 }, MasterKeyWrappedUserKey: encrypted
  } };
  check(LoginResponseUtil.normalize(token, params, 'test@example.com').encryptedUserKey === encrypted,
    'PascalCase wrapped key');
  token.userDecryptionOptions.MasterPasswordUnlock!.MasterKeyWrappedUserKey = '7.unsupported';
  token.userDecryptionOptions.MasterPasswordUnlock!.MasterKeyEncryptedUserKey = encrypted;
  let rejected = false;
  try {
    LoginResponseUtil.normalize(token, params, 'test@example.com');
  } catch (error) {
    rejected = (error as Error).message === DECRYPTION_UNSUPPORTED;
  }
  check(rejected, 'invalid wrapped key cannot fall back');
  check(!LogSanitizer.sanitize('{"masterKeyWrappedUserKey":"short_secret"}').includes('short_secret'),
    'wrapped key redacted');
}
