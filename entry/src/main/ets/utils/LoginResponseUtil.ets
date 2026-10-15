import { AccessTokenResponse } from '../model/AccessToken';
import { KdfParameters } from '../model/Prelogin';
import { KdfUtil } from './KdfUtil';

export interface LoginDecryptionMaterial {
  params: KdfParameters;
  encryptedUserKey: string;
  encryptedPrivateKey?: string;
  source: string;
}

export const PASSWORD_RESET_REQUIRED = 'password_reset_required';
export const DECRYPTION_UNSUPPORTED = 'account_decryption_unsupported';

/** 新字段优先；缺少主密码解密方式时，不能以旧字段绕过账号的解密要求。 */
export class LoginResponseUtil {
  static normalize(response: AccessTokenResponse, authentication: KdfParameters,
    email: string): LoginDecryptionMaterial {
    if (response.ForcePasswordReset === true || response.forcePasswordReset === true) {
      throw new Error(PASSWORD_RESET_REQUIRED);
    }
    if (!response.access_token || !response.refresh_token || !Number.isFinite(response.expires_in) ||
      response.expires_in <= 0) {
      throw new Error('Invalid password token response');
    }
    const options = response.userDecryptionOptions ?? response.UserDecryptionOptions;
    const unlock = options?.masterPasswordUnlock ?? options?.MasterPasswordUnlock;
    let params = authentication;
    let userKey = response.key ?? response.Key ?? '';
    if (unlock) {
      const kdf = unlock.kdf ?? unlock.Kdf;
      params = KdfUtil.normalize({
        kdfSettings: {
          kdfType: kdf?.kdfType ?? kdf?.KdfType ?? -1,
          iterations: kdf?.iterations ?? kdf?.Iterations ?? -1,
          memory: kdf?.memory ?? kdf?.Memory,
          parallelism: kdf?.parallelism ?? kdf?.Parallelism
        },
        salt: unlock.salt ?? unlock.Salt
      }, email);
      // wrapped 是标准名；存在但无效时拒绝，不能回退到旧字段绕过校验。
      if (unlock.masterKeyWrappedUserKey !== undefined) {
        userKey = unlock.masterKeyWrappedUserKey;
      } else if (unlock.MasterKeyWrappedUserKey !== undefined) {
        userKey = unlock.MasterKeyWrappedUserKey;
      } else {
        userKey = unlock.masterKeyEncryptedUserKey ?? unlock.MasterKeyEncryptedUserKey ?? '';
      }
    } else if (options && (options.hasMasterPassword ?? options.HasMasterPassword) !== true) {
      throw new Error(DECRYPTION_UNSUPPORTED);
    }
    const accountKeys = response.accountKeys ?? response.AccountKeys;
    const pair = accountKeys?.publicKeyEncryptionKeyPair ?? accountKeys?.PublicKeyEncryptionKeyPair;
    const privateKey = pair?.wrappedPrivateKey ?? pair?.WrappedPrivateKey ?? response.privateKey ?? response.PrivateKey;
    if (!LoginResponseUtil.isSupportedEncryptedString(userKey) ||
      (privateKey !== undefined && privateKey !== null && privateKey.length > 0 &&
        !LoginResponseUtil.isSupportedEncryptedString(privateKey))) {
      throw new Error(DECRYPTION_UNSUPPORTED);
    }
    return {
      params: params,
      encryptedUserKey: userKey,
      encryptedPrivateKey: privateKey || undefined,
      source: unlock ? 'modern' : 'legacy'
    };
  }

  static sameKdf(left: KdfParameters, right: KdfParameters): boolean {
    return left.kdf === right.kdf && left.kdfIterations === right.kdfIterations &&
      left.kdfMemory === right.kdfMemory && left.kdfParallelism === right.kdfParallelism &&
      left.salt === right.salt;
  }

  private static isSupportedEncryptedString(value: string | null | undefined): boolean {
    // 现有密码库支持 AES-256-CBC/HMAC 的 64 字节用户密钥，不能接受其他密钥格式。
    return typeof value === 'string' && /^2\.[^|]+\|[^|]+\|[^|]+$/.test(value);
  }
}
