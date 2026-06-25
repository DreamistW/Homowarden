import { Cipher, CipherCard, CipherIdentity, CipherLogin, CipherSecureNote, CipherUri } from '../model/CipherModels';
import { CardBrandType, CipherItemType, IdentityTitleType } from '../utils/Constants';
import { CryptoUtil } from '../utils/CryptoUtil';
import { createCipher } from '../network/CipherApi';
import { DeviceUtil } from '../utils/DeviceUtil';
import { IBestDropdownMenuOption } from '@ibestservices/ibest-ui';
import { DatabaseUtil } from '../utils/DatabaseUtil';

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
  identityTitleOptions: IBestDropdownMenuOption[] =
    [
      { text: '无', value: IdentityTitleType.NONE },
      { text: '先生', value: IdentityTitleType.MR },
      { text: '夫人', value: IdentityTitleType.MRS },
      { text: '女士', value: IdentityTitleType.MISS },
      { text: 'Mx', value: IdentityTitleType.MX },
      { text: '博士', value: IdentityTitleType.DR }
    ];
  cardBrandOptions: IBestDropdownMenuOption[] =
    [
      { text: '无', value: CardBrandType.NONE },
      { text: 'Visa', value: CardBrandType.VISA },
      { text: 'MasterCard', value: CardBrandType.MASTER },
      { text: 'American Express', value: CardBrandType.AME },
      { text: 'Discover', value: CardBrandType.DISCOVER },
      { text: 'Diners Club', value: CardBrandType.DINERS },
      { text: 'JCB', value: CardBrandType.JCB },
      { text: 'Maestro', value: CardBrandType.MAESTRO },
      { text: 'UnionPay', value: CardBrandType.UNIONPAY },
      { text: 'RuPay', value: CardBrandType.RUPAY },
      { text: '其他', value: CardBrandType.OTHER },
    ];

  canSave(): boolean {
    return this.name.trim().length > 0;
  }

  // 构建加密登录项
  private async buildEncryptedLogin(): Promise<CipherLogin> {
    const encUsername =
      this.loginItem.username ? await CryptoUtil.encryptField(this.loginItem.username, this.symmetricKey) : null;
    const encPassword =
      this.loginItem.password ? await CryptoUtil.encryptField(this.loginItem.password, this.symmetricKey) : null;
    const encTotp =
      this.loginItem.totp ? await CryptoUtil.encryptField(this.loginItem.totp, this.symmetricKey) : null;

    let encUris: CipherUri[] = [];
    if (this.loginUri.uri) {
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
      totp: encTotp,
      uris: encUris
    };
    return login;
  }

  // 构建加密安全笔记
  private async buildEncryptedNote(): Promise<CipherSecureNote> {
    const note: CipherSecureNote = {
      type: this.noteItem.type
    };
    return note;
  }

  // 构建加密卡片
  private async buildEncryptedCard(): Promise<CipherCard> {
    const encNumber =
      this.cardItem.number ? await CryptoUtil.encryptField(this.cardItem.number, this.symmetricKey) : '';
    const encHolderName =
      this.cardItem.cardholderName ? await CryptoUtil.encryptField(this.cardItem.cardholderName, this.symmetricKey) :
        '';
    const encBrand = this.cardItem.brand ? await CryptoUtil.encryptField(this.cardItem.brand, this.symmetricKey) : '';
    const encExpMonth =
      this.cardItem.expMonth ? await CryptoUtil.encryptField(this.cardItem.expMonth, this.symmetricKey) : '';
    const encExpYear =
      this.cardItem.expYear ? await CryptoUtil.encryptField(this.cardItem.expYear, this.symmetricKey) : '';
    const encCode = this.cardItem.code ? await CryptoUtil.encryptField(this.cardItem.code, this.symmetricKey) : '';

    const card: CipherCard = {
      cardholderName: encHolderName,
      brand: encBrand,
      number: encNumber,
      expMonth: encExpMonth,
      expYear: encExpYear,
      code: encCode
    };

    return card;
  }

  // 构建加密身份信息
  private async buildEncryptedIdentity(): Promise<CipherIdentity> {
    const encAddress1 =
      this.identityItem.address1 ? await CryptoUtil.encryptField(this.identityItem.address1, this.symmetricKey) : '';
    const encAddress2 =
      this.identityItem.address2 ? await CryptoUtil.encryptField(this.identityItem.address2, this.symmetricKey) : '';
    const encAddress3 =
      this.identityItem.address3 ? await CryptoUtil.encryptField(this.identityItem.address3, this.symmetricKey) : '';
    const encCity =
      this.identityItem.city ? await CryptoUtil.encryptField(this.identityItem.city, this.symmetricKey) : '';
    const encCompany =
      this.identityItem.company ? await CryptoUtil.encryptField(this.identityItem.company, this.symmetricKey) : '';
    const encCountry =
      this.identityItem.country ? await CryptoUtil.encryptField(this.identityItem.country, this.symmetricKey) : '';
    const encEmail =
      this.identityItem.email ? await CryptoUtil.encryptField(this.identityItem.email, this.symmetricKey) : '';
    const encFirstName =
      this.identityItem.firstName ? await CryptoUtil.encryptField(this.identityItem.firstName, this.symmetricKey) : '';
    const encLastName =
      this.identityItem.lastName ? await CryptoUtil.encryptField(this.identityItem.lastName, this.symmetricKey) : '';
    const encLicenseNumber = this.identityItem.licenseNumber ?
      await CryptoUtil.encryptField(this.identityItem.licenseNumber, this.symmetricKey) : '';
    const encMiddleName =
      this.identityItem.middleName ? await CryptoUtil.encryptField(this.identityItem.middleName, this.symmetricKey) :
        '';
    const encPassportNumber = this.identityItem.passportNumber ?
      await CryptoUtil.encryptField(this.identityItem.passportNumber, this.symmetricKey) : '';
    const encPhone =
      this.identityItem.phone ? await CryptoUtil.encryptField(this.identityItem.phone, this.symmetricKey) : '';
    const encPostalCode =
      this.identityItem.postalCode ? await CryptoUtil.encryptField(this.identityItem.postalCode, this.symmetricKey) :
        '';
    const encSSN = this.identityItem.ssn ? await CryptoUtil.encryptField(this.identityItem.ssn, this.symmetricKey) : '';
    const encState =
      this.identityItem.state ? await CryptoUtil.encryptField(this.identityItem.state, this.symmetricKey) : '';
    const encTitle =
      this.identityItem.title ? await CryptoUtil.encryptField(this.identityItem.title, this.symmetricKey) : '';
    const encUsername =
      this.identityItem.username ? await CryptoUtil.encryptField(this.identityItem.username, this.symmetricKey) : '';

    const identity: CipherIdentity = {
      address1: encAddress1,
      address2: encAddress2,
      address3: encAddress3,
      city: encCity,
      company: encCompany,
      country: encCountry,
      email: encEmail,
      firstName: encFirstName,
      lastName: encLastName,
      licenseNumber: encLicenseNumber,
      middleName: encMiddleName,
      passportNumber: encPassportNumber,
      phone: encPhone,
      postalCode: encPostalCode,
      ssn: encSSN,
      state: encState,
      title: encTitle,
      username: encUsername
    };

    return identity;
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
      type: this.type,
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
      card: this.type == CipherItemType.CARD ? await this.buildEncryptedCard() : null,
      identity: this.type == CipherItemType.IDENTITY ? await this.buildEncryptedIdentity() : null,
      secureNote: this.type == CipherItemType.NOTE ? await this.buildEncryptedNote() : null,
      fields: [],
      collectionIds: [],
      reprompt: 0,
    };
    return cipher;
  }

  private buildCreatedEncryptedCipher(payload: Cipher, createdCipher: Cipher): Cipher {
    const revisionDate = createdCipher.revisionDate || payload.revisionDate;

    return {
      id: createdCipher.id || payload.id,
      type: createdCipher.type || payload.type,
      name: createdCipher.name || payload.name,
      favorite: createdCipher.favorite === undefined ? payload.favorite : createdCipher.favorite,
      edit: createdCipher.edit === undefined ? payload.edit : createdCipher.edit,
      viewPassword: createdCipher.viewPassword,
      folderId: createdCipher.folderId === undefined ? payload.folderId : createdCipher.folderId,
      organizationId: createdCipher.organizationId === undefined ? payload.organizationId : createdCipher.organizationId,
      creationDate: createdCipher.creationDate || payload.creationDate,
      revisionDate: revisionDate,
      lastKnownRevisionDate: revisionDate,
      deletedDate: createdCipher.deletedDate === undefined ? payload.deletedDate : createdCipher.deletedDate,
      archivedDate: createdCipher.archivedDate === undefined ? payload.archivedDate || null : createdCipher.archivedDate,
      notes: createdCipher.notes === undefined ? payload.notes : createdCipher.notes,
      login: createdCipher.login === undefined ? payload.login : createdCipher.login,
      card: createdCipher.card === undefined ? payload.card : createdCipher.card,
      identity: createdCipher.identity === undefined ? payload.identity : createdCipher.identity,
      secureNote: createdCipher.secureNote === undefined ? payload.secureNote : createdCipher.secureNote,
      sshKey: createdCipher.sshKey === undefined ? payload.sshKey || null : createdCipher.sshKey,
      bankAccount: createdCipher.bankAccount === undefined ? payload.bankAccount || null : createdCipher.bankAccount,
      driversLicense: createdCipher.driversLicense === undefined ? payload.driversLicense || null :
        createdCipher.driversLicense,
      passport: createdCipher.passport === undefined ? payload.passport || null : createdCipher.passport,
      fields: createdCipher.fields === undefined ? payload.fields || [] : createdCipher.fields,
      collectionIds: createdCipher.collectionIds === undefined ? payload.collectionIds || [] : createdCipher.collectionIds,
      passwordHistory: createdCipher.passwordHistory === undefined ? payload.passwordHistory || null :
        createdCipher.passwordHistory,
      attachments: createdCipher.attachments === undefined ? payload.attachments || null : createdCipher.attachments,
      attachments2: createdCipher.attachments2 === undefined ? payload.attachments2 || null : createdCipher.attachments2,
      key: createdCipher.key === undefined ? payload.key || null : createdCipher.key,
      encryptedFor: createdCipher.encryptedFor === undefined ? payload.encryptedFor || null : createdCipher.encryptedFor,
      reprompt: createdCipher.reprompt === undefined || createdCipher.reprompt === null ? payload.reprompt :
        createdCipher.reprompt
    };
  }

  private buildCreatedPlainCipher(createdCipher: Cipher): Cipher {
    const revisionDate = createdCipher.revisionDate;
    const notes = this.notes && this.notes.trim().length > 0 ? this.notes.trim() : null;

    return {
      id: createdCipher.id,
      type: this.type,
      name: this.name.trim(),
      favorite: createdCipher.favorite,
      edit: createdCipher.edit,
      viewPassword: createdCipher.viewPassword,
      folderId: createdCipher.folderId,
      organizationId: createdCipher.organizationId,
      creationDate: this.formatDateTime(createdCipher.creationDate),
      revisionDate: this.formatDateTime(revisionDate),
      lastKnownRevisionDate: revisionDate,
      deletedDate: null,
      archivedDate: createdCipher.archivedDate || null,
      notes: notes,
      login: this.type == CipherItemType.LOGIN ? this.buildPlainLogin() : null,
      card: this.type == CipherItemType.CARD ? this.buildPlainCard() : null,
      identity: this.type == CipherItemType.IDENTITY ? this.buildPlainIdentity() : null,
      secureNote: this.type == CipherItemType.NOTE ? this.noteItem : null,
      fields: [],
      collectionIds: createdCipher.collectionIds || [],
      passwordHistory: null,
      attachments: null,
      attachments2: null,
      key: null,
      encryptedFor: createdCipher.encryptedFor || null,
      reprompt: createdCipher.reprompt
    };
  }

  private buildPlainLogin(): CipherLogin {
    const uri = this.loginUri.uri ? this.loginUri.uri.trim() : '';
    const uris: CipherUri[] = uri ? [{
      uri: uri,
      uriChecksum: '',
      match: this.loginUri.match ?? null
    }] : [];

    return {
      username: this.loginItem.username || null,
      password: this.loginItem.password || null,
      passwordRevisionDate: null,
      totp: this.loginItem.totp || null,
      uris: uris
    };
  }

  private buildPlainCard(): CipherCard {
    return {
      cardholderName: this.cardItem.cardholderName || null,
      brand: this.cardItem.brand || null,
      number: this.cardItem.number || null,
      expMonth: this.cardItem.expMonth || null,
      expYear: this.cardItem.expYear || null,
      code: this.cardItem.code || null
    };
  }

  private buildPlainIdentity(): CipherIdentity {
    return {
      address1: this.identityItem.address1 || null,
      address2: this.identityItem.address2 || null,
      address3: this.identityItem.address3 || null,
      city: this.identityItem.city || null,
      company: this.identityItem.company || null,
      country: this.identityItem.country || null,
      email: this.identityItem.email || null,
      firstName: this.identityItem.firstName || null,
      lastName: this.identityItem.lastName || null,
      licenseNumber: this.identityItem.licenseNumber || null,
      middleName: this.identityItem.middleName || null,
      passportNumber: this.identityItem.passportNumber || null,
      phone: this.identityItem.phone || null,
      postalCode: this.identityItem.postalCode || null,
      ssn: this.identityItem.ssn || null,
      state: this.identityItem.state || null,
      title: this.identityItem.title || null,
      username: this.identityItem.username || null
    };
  }

  private formatDateTime(dateStr: string): string {
    if (!dateStr) {
      return '---';
    }
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }

  // 提交新建密码项
  async submitCreate(): Promise<Cipher | null> {
    this.errorMessage = '';
    if (!this.canSave()) {
      this.errorMessage = '请填写名称';
      return null;
    }
    try {
      this.submitting = true;
      const payload = await this.buildEncryptedCipher();
      const createdCipher = this.buildCreatedEncryptedCipher(payload, await createCipher(payload));
      await DatabaseUtil.getInstance().saveCipherToDatabase(createdCipher);
      return this.buildCreatedPlainCipher(createdCipher);
    } catch (err) {
      this.errorMessage = `创建失败, 错误信息: ${JSON.stringify(err)}`;
      return null;
    } finally {
      this.submitting = false;
    }
  }
}
