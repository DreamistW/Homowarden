import { Logger } from '@nzy/logger';
import { Cipher, CipherLogin } from '../model/CipherModels';
import { PreloginResponse } from '../model/Prelogin';
import { queryAssetSync } from '../utils/AssetUtil';
import { CipherItemType, DBTableName, EMAIL_KEY, KDF_PARAM_KEY, MASTER_KEY } from '../utils/Constants';
import { CryptoUtil } from '../utils/CryptoUtil';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { AppText, AppTextKey } from '../localization/AppText';
import { relationalStore } from '@kit.ArkData';

/**
 * 解密包含 TOTP 的登录项，并在查看详情前重新验证主密码。
 */
export class TotpListViewModel {
  allCiphers: Cipher[] = [];
  // 筛选后的密码项
  filteredCiphers: Cipher[] = [];
  // 对称密钥
  symmetricKey: string = '';
  // 错误信息
  errorMessage: AppText | undefined = undefined;

  /**
   * 解密配置了 TOTP 的登录项，完成后仅暴露带有 TOTP 的条目。
   *
   * 性能要点：
   * 1) 用一次同步批量查询拉取 cipher_logins 全表，避免逐条 querySingleData 在主线程上
   *    串行同步查询造成 Tab 切换动画卡顿（之前的"首次点击后卡数秒"问题即此导致）。
   * 2) TOTP 列表只关心配置了 TOTP 密文的登录项：先按同步预取的密文过滤，再决定是否解密，
   *    绝大多数没有 TOTP 的登录项完全跳过 cipher key / username 的解密。
   * 3) 仅对确有 TOTP 密文的少量登录项并发解密；单条失败不阻塞其余项。
   */
  async loadLogins(): Promise<void> {
    const loginRows: relationalStore.ValuesBucket[] =
      DatabaseUtil.getInstance().queryAllRowsSync(DBTableName.LOGINS, ['cipher_id', 'username', 'totp']);
    const loginRowByCipherId: Map<string, relationalStore.ValuesBucket> = new Map();
    for (const row of loginRows) {
      const cipherIdRaw = row.cipher_id;
      if (cipherIdRaw !== null && cipherIdRaw !== undefined) {
        loginRowByCipherId.set(cipherIdRaw.toString(), row);
      }
    }

    const loginCiphers: Cipher[] =
      this.allCiphers.filter(cipher => cipher.type === CipherItemType.LOGIN);
    const emptyLogin: CipherLogin = {
      username: '', totp: '', password: null, passwordRevisionDate: null, uris: []
    };
    const ciphersWithTotp: Cipher[] = [];
    for (const cipher of loginCiphers) {
      const row = loginRowByCipherId.get(cipher.id);
      const encTotp = row ? (row.totp as string) : '';
      if (encTotp && encTotp.length > 0) {
        ciphersWithTotp.push(cipher);
      } else {
        cipher.login = emptyLogin;
      }
    }

    await Promise.all(ciphersWithTotp.map(async (cipher) => {
      const row = loginRowByCipherId.get(cipher.id);
      if (!row) {
        cipher.login = emptyLogin;
        return;
      }
      const encTotp = row.totp as string;
      const encUsername = row.username as string;
      try {
        const cipherKey = await CryptoUtil.decryptCipherKey(cipher.key, this.symmetricKey);
        const totp = await CryptoUtil.decryptField(encTotp, cipherKey);
        let username: string = '';
        if (totp && totp.length > 0 && encUsername && encUsername.length > 0) {
          username = await CryptoUtil.decryptField(encUsername, cipherKey);
        }
        cipher.login = {
          username: username, totp: totp, password: null, passwordRevisionDate: null, uris: []
        };
      } catch (err) {
        Logger.error(`Failed to load login for cipher ${cipher.id}: ${err}`);
        cipher.login = emptyLogin;
      }
    }));

    this.filteredCiphers = loginCiphers.filter(cipher => !!cipher.login?.totp);
  }

  /**
   * 按登录时保存的 KDF 参数重新派生主密钥，不直接保存或比较主密码明文。
   */
  async verifyMasterPassword(passwordInput: string): Promise<boolean> {
    if (!passwordInput || passwordInput.length === 0) {
      this.errorMessage = new AppText(AppTextKey.MASTER_PASSWORD_REQUIRED);
      return false;
    }

    try {
      // 获取存储的 KDF 参数
      const kdfParamStr: string = queryAssetSync(KDF_PARAM_KEY);
      if (!kdfParamStr) {
        this.errorMessage = new AppText(AppTextKey.PARAMETERS_FAILED);
        return false;
      }

      const kdfParams: PreloginResponse = JSON.parse(kdfParamStr);
      const storedMasterKey = queryAssetSync(MASTER_KEY);
      const email = queryAssetSync(EMAIL_KEY);

      if (!storedMasterKey) {
        this.errorMessage = new AppText(AppTextKey.PARAMETERS_FAILED);
        return false;
      }

      // 使用输入的密码重新派生主密钥
      let derivedMasterKey: string = '';
      const salt = email.trim().toLowerCase() || '';

      if (kdfParams.kdf === 0) {
        // PBKDF2
        derivedMasterKey = await CryptoUtil.deriveKeyPBKDF2(
          passwordInput,
          salt,
          kdfParams.kdfIterations || 100000,
          32
        );
      } else if (kdfParams.kdf === 1) {
        // Argon2id
        derivedMasterKey = await CryptoUtil.deriveKeyArgon2id(
          passwordInput,
          salt,
          kdfParams.kdfIterations || 2,
          kdfParams.kdfMemory || 16,
          kdfParams.kdfParallelism || 1,
          32
        );
      } else {
        this.errorMessage = new AppText(AppTextKey.KDF_UNSUPPORTED);
        return false;
      }

      // 验证派生的主密钥是否与存储的匹配
      if (derivedMasterKey === storedMasterKey) {
        return true;
      } else {
        this.errorMessage = new AppText(AppTextKey.MASTER_PASSWORD_WRONG);
        return false;
      }
    } catch (error) {
      Logger.error(`Master password verification failed: ${error}`);
      this.errorMessage = new AppText(AppTextKey.VERIFICATION_FAILED);
      return false;
    }
  }
}
