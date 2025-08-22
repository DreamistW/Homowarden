import { Cipher, CipherCard, CipherIdentity, CipherLogin, CipherSecureNote, CipherUri } from '../model/CipherModels';
import { CipherItemType } from '../utils/Constants';
import { CryptoUtil } from '../utils/CryptoUtil';
import { createCipher } from '../network/CipherApi';
import { DeviceUtil } from '../utils/DeviceUtil';

export class AddCipherViewModel {
  type: CipherItemType = CipherItemType.LOGIN;
  // 对称密钥
  symmetricKey: string = '';
  // 表单字段
  name: string = '';
  loginItem: CipherLogin = {} as CipherLogin;
  loginUri: CipherUri = {} as CipherUri;
  noteItem: CipherSecureNote = {} as CipherSecureNote;
  cardItem: CipherCard = {} as CipherCard;
  identityItem: CipherIdentity = {} as CipherIdentity;
  notes: string = '';
  // 页面状态
  submitting: boolean = false;
  errorMessage: string = '';

  canSave(): boolean {
    return this.name.trim().length > 0;
  }

  // 构建加密登录项
  private async buildEncryptedLogin(): Promise<CipherLogin> {
    const encUsername =
      this.loginItem.username ? await CryptoUtil.encryptField(this.loginItem.username, this.symmetricKey) : '';
    const encPassword =
      this.loginItem.password ? await CryptoUtil.encryptField(this.loginItem.password, this.symmetricKey) : '';

    let encUris: CipherUri[] = [];
    if (this.loginUri) {
      const encUrl = await CryptoUtil.encryptField(this.loginUri.uri.trim(), this.symmetricKey);
      const sha256CheckSum = await CryptoUtil.doSha256(this.loginUri.uri.trim());
      const encChecksum = await CryptoUtil.encryptField(sha256CheckSum, this.symmetricKey);
      encUris.push({
        uri: encUrl,
        uriChecksum: encChecksum
      });
    }

    const login: CipherLogin = {
      username: encUsername,
      password: encPassword,
      passwordRevisionDate: null,
      totp: null,
      uris: encUris
    };
    return login;
  }

  // 构建加密项目
  private async buildEncryptedCipher(): Promise<Cipher> {
    const encName = await CryptoUtil.encryptField(this.name.trim(), this.symmetricKey);
    const encNotes = this.notes && this.notes.trim().length > 0
      ? await CryptoUtil.encryptField(this.notes.trim(), this.symmetricKey)
      : null;
    const timestamp = DeviceUtil.getISOTimestamp();

    const cipher: Cipher = {
      id: DeviceUtil.generateUUID(),
      type: CipherItemType.LOGIN,
      name: encName,
      favorite: false,
      edit: true,
      folderId: null,
      organizationId: null,
      creationDate: timestamp,
      revisionDate: timestamp,
      deletedDate: null,
      notes: encNotes,
      login: this.type == CipherItemType.LOGIN ? await this.buildEncryptedLogin() : null,
      card: null,
      identity: null,
      secureNote: null,
      fields: [],
      collectionIds: [],
      reprompt: 0,
    };
    return cipher;
  }

  // 提交新建密码项
  async submitCreate(): Promise<boolean> {
    this.errorMessage = '';
    if (!this.canSave()) {
      this.errorMessage = '请填写名称';
      return false;
    }
    try {
      this.submitting = true;
      const payload = await this.buildEncryptedCipher();
      await createCipher(payload);
      return true;
    } catch (err) {
      this.errorMessage = '创建失败，请重试';
      return false;
    } finally {
      this.submitting = false;
    }
  }
}