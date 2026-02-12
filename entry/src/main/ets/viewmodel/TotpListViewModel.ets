import { Logger } from '@nzy/logger';
import { Cipher, CipherLogin } from '../model/CipherModels';
import { PreloginResponse } from '../model/Prelogin';
import { queryAssetSync } from '../utils/AssetUtil';
import { CipherItemType, DBTableName, EMAIL_KEY, KDF_PARAM_KEY, MASTER_KEY } from '../utils/Constants';
import { CryptoUtil } from '../utils/CryptoUtil';
import { DatabaseUtil } from '../utils/DatabaseUtil';

export class TotpListViewModel {
  allCiphers: Cipher[] = [];
  // 筛选后的密码项
  filteredCiphers: Cipher[] = [];
  // 对称密钥
  symmetricKey: string = '';
  // 错误信息
  errorMessage: string = '';

  async loadLogins() {
    // 遍历所有密码项
    for (const cipher of this.allCiphers) {
      if (cipher.type == CipherItemType.LOGIN) {
        // 获取登录项信息
        cipher.login = await this.getCipherLogin(cipher.id);
      }
    }
    this.filteredCiphers = this.allCiphers.filter(cipher => cipher.type == CipherItemType.LOGIN && cipher.login?.totp)
  }

  async verifyMasterPassword(passwordInput: string): Promise<boolean> {
    if (!passwordInput || passwordInput.length === 0) {
      this.errorMessage = '请输入主密码';
      return false;
    }

    try {
      // 获取存储的 KDF 参数
      const kdfParamStr: string = queryAssetSync(KDF_PARAM_KEY);
      if (!kdfParamStr) {
        this.errorMessage = '无法获取 KDF 参数，请重新登录';
        return false;
      }

      const kdfParams: PreloginResponse = JSON.parse(kdfParamStr);
      const storedMasterKey = queryAssetSync(MASTER_KEY);
      const email = queryAssetSync(EMAIL_KEY);

      if (!storedMasterKey) {
        this.errorMessage = '无法获取主密钥，请重新登录';
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
        this.errorMessage = '不支持的 KDF 类型';
        return false;
      }

      // 验证派生的主密钥是否与存储的匹配
      if (derivedMasterKey === storedMasterKey) {
        return true;
      } else {
        this.errorMessage = '主密码错误';
        return false;
      }
    } catch (error) {
      Logger.error(`Master password verification failed: ${error}`);
      this.errorMessage = '验证失败，请重试';
      return false;
    }
  }

  /**
   * 获取登录信息
   */
  private async getCipherLogin(cipherId: string): Promise<CipherLogin> {
    return new Promise(async (resolve) => {
      const encUsername =
        DatabaseUtil.getInstance().querySingleData(DBTableName.LOGINS, 'cipher_id', cipherId, 'username');
      const username = await CryptoUtil.decryptField(encUsername as string, this.symmetricKey);
      const encTotp = DatabaseUtil.getInstance().querySingleData(DBTableName.LOGINS, 'cipher_id', cipherId, 'totp');
      const totp = await CryptoUtil.decryptField(encTotp as string, this.symmetricKey);
      const loginItem: CipherLogin = {
        username: username,
        totp: totp,
        password: null,
        passwordRevisionDate: null,
        uris: []
      };
      resolve(loginItem);
    })
  }
}