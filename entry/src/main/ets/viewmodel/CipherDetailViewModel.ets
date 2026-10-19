import { Logger } from '@nzy/logger';
import {
  Cipher,
  CipherCard,
  CipherField,
  CipherIdentity,
  CipherLogin,
  CipherSecureNote,
  CipherUri
} from '../model/CipherModels';
import { CipherFieldType, CipherItemType, DBTableName } from '../utils/Constants';
import { CryptoUtil } from '../utils/CryptoUtil';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import {
  deleteCipher,
  moveCipherToRecycler,
  restoreCipher,
  updateCipher as updateCipherApi,
  updateCipherPartial as updateCipherPartialApi
} from '../network/CipherApi';
import { DeviceUtil } from '../utils/DeviceUtil';
import { relationalStore } from '@kit.ArkData';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

/**
 * 负责密码项详情的本地解密、远端变更及加密数据落库
 */
export class CipherDetailViewModel {
  symmetricKey: string = '';
  private cipherKey: string = '';
  private isCipherDecrypted: boolean = false;
  private batchRows: Map<string, relationalStore.ValuesBucket[]> | null = null;

  /** 导出时只读取一次详情子表，避免逐条全表查询。普通详情页仍实时读取。 */
  async prepareBatchRead(): Promise<void> {
    const rows: Map<string, relationalStore.ValuesBucket[]> = new Map();
    for (const table of [DBTableName.LOGINS, DBTableName.CARDS, DBTableName.IDENTITIES,
      DBTableName.NOTES, DBTableName.FIELDS]) {
      rows.set(table, await DatabaseUtil.getInstance().queryAllData(table));
    }
    this.batchRows = rows;
  }

  clearBatchRead(): void {
    this.batchRows = null;
    this.cipherKey = '';
    this.symmetricKey = '';
  }

  private async queryDetailRows(table: string): Promise<relationalStore.ValuesBucket[]> {
    return this.batchRows?.get(table) ?? await DatabaseUtil.getInstance().queryAllData(table);
  }

  /**
   * 获取完整的密码项详情
   */
  async getCipherDetail(cipher: Cipher): Promise<Cipher> {
    this.isCipherDecrypted = false;
    // 从此处开始填充供界面使用的明文对象，完成前禁止进入编辑保存流程
    this.cipherKey = await CryptoUtil.decryptCipherKey(cipher.key, this.symmetricKey);
    // 根据类型获取详细信息
    switch (cipher.type) {
      case CipherItemType.LOGIN:
        cipher.login = await this.getCipherLogin(cipher.id);
        break;
      case CipherItemType.NOTE:
        cipher.secureNote = await this.getCipherSecureNote(cipher.id);
        break;
      case CipherItemType.CARD:
        cipher.card = await this.getCipherCard(cipher.id);
        break;
      case CipherItemType.IDENTITY:
        cipher.identity = await this.getCipherIdentity(cipher.id);
        break;
    }

    // 获取自定义字段
    cipher.fields = await this.getCipherFields(cipher.id);
    this.isCipherDecrypted = true;
    return cipher;
  }

  /**
   * 获取登录信息
   */
  private async getCipherLogin(cipherId: string): Promise<CipherLogin> {
    const loginData = await this.queryDetailRows(DBTableName.LOGINS);
    const loginRecord = loginData.find(data => data.cipher_id === cipherId);
    if (!loginRecord) {
      throw new Error(`Cipher login not found: ${cipherId}`);
    }
    const username = await CryptoUtil.decryptField(loginRecord.username as string, this.cipherKey);
    const password = await CryptoUtil.decryptField(loginRecord.password as string, this.cipherKey);
    const totp = await CryptoUtil.decryptField(loginRecord.totp as string, this.cipherKey);
    let uris: CipherUri[] = [];
    if (loginRecord.uris) {
      uris = await this.parseUris(JSON.parse(loginRecord.uris as string));
    }
    const loginItem: CipherLogin = {
      username: username,
      password: password,
      passwordRevisionDate: loginRecord.password_revision_date as string || null,
      totp: totp,
      uris: uris
    };
    return loginItem;
  }

  // 解析URI数组
  async parseUris(uris: CipherUri[]): Promise<CipherUri[]> {
    return await Promise.all(
      uris.map(async (item: CipherUri) => {
        item.uri = await CryptoUtil.decryptField(item.uri, this.cipherKey);
        item.uriChecksum = await CryptoUtil.decryptField(item.uriChecksum, this.cipherKey);
        return item;
      })
    );
  }

  /**
   * 获取卡片信息
   */
  private async getCipherCard(cipherId: string): Promise<CipherCard> {
    const cardData = await this.queryDetailRows(DBTableName.CARDS);
    const cardRecord = cardData.find(data => data.cipher_id === cipherId);
    if (!cardRecord) {
      throw new Error(`Cipher card not found: ${cipherId}`);
    }
    const cardholderName = await CryptoUtil.decryptField(cardRecord.cardholder_name as string, this.cipherKey);
    const brand = await CryptoUtil.decryptField(cardRecord.brand as string, this.cipherKey);
    const number = await CryptoUtil.decryptField(cardRecord.number as string, this.cipherKey);
    const expMonth = await CryptoUtil.decryptField(cardRecord.exp_month as string, this.cipherKey);
    const expYear = await CryptoUtil.decryptField(cardRecord.exp_year as string, this.cipherKey);
    const code = await CryptoUtil.decryptField(cardRecord.code as string, this.cipherKey);
    const cardItem: CipherCard = {
      cardholderName: cardholderName,
      brand: brand,
      number: number,
      expMonth: expMonth,
      expYear: expYear,
      code: code
    };
    return cardItem;
  }

  /**
   * 获取身份信息
   */
  private async getCipherIdentity(cipherId: string): Promise<CipherIdentity> {
    const identityData = await this.queryDetailRows(DBTableName.IDENTITIES);
    const identityRecord = identityData.find(data => data.cipher_id === cipherId);
    if (!identityRecord) {
      throw new Error(`Cipher identity not found: ${cipherId}`);
    }
    const address1 = await CryptoUtil.decryptField(identityRecord.address1 as string, this.cipherKey);
    const address2 = await CryptoUtil.decryptField(identityRecord.address2 as string, this.cipherKey);
    const address3 = await CryptoUtil.decryptField(identityRecord.address3 as string, this.cipherKey);
    const city = await CryptoUtil.decryptField(identityRecord.city as string, this.cipherKey);
    const company = await CryptoUtil.decryptField(identityRecord.company as string, this.cipherKey);
    const country = await CryptoUtil.decryptField(identityRecord.country as string, this.cipherKey);
    const email = await CryptoUtil.decryptField(identityRecord.email as string, this.cipherKey);
    const firstName = await CryptoUtil.decryptField(identityRecord.first_name as string, this.cipherKey);
    const lastName = await CryptoUtil.decryptField(identityRecord.last_name as string, this.cipherKey);
    const licenseNumber = await CryptoUtil.decryptField(identityRecord.license_number as string, this.cipherKey);
    const middleName = await CryptoUtil.decryptField(identityRecord.middle_name as string, this.cipherKey);
    const passportNumber = await CryptoUtil.decryptField(identityRecord.passport_number as string, this.cipherKey);
    const phone = await CryptoUtil.decryptField(identityRecord.phone as string, this.cipherKey);
    const postalCode = await CryptoUtil.decryptField(identityRecord.postal_code as string, this.cipherKey);
    const ssn = await CryptoUtil.decryptField(identityRecord.ssn as string, this.cipherKey);
    const state = await CryptoUtil.decryptField(identityRecord.state as string, this.cipherKey);
    const title = await CryptoUtil.decryptField(identityRecord.title as string, this.cipherKey);
    const username = await CryptoUtil.decryptField(identityRecord.username as string, this.cipherKey);
    const identityItem: CipherIdentity = {
      address1: address1,
      address2: address2,
      address3: address3,
      city: city,
      company: company,
      country: country,
      email: email,
      firstName: firstName,
      lastName: lastName,
      licenseNumber: licenseNumber,
      middleName: middleName,
      passportNumber: passportNumber,
      phone: phone,
      postalCode: postalCode,
      ssn: ssn,
      state: state,
      title: title,
      username: username
    };
    return identityItem;
  }

  /**
   * 获取安全笔记
   */
  private async getCipherSecureNote(cipherId: string): Promise<CipherSecureNote> {
    const noteData = await this.queryDetailRows(DBTableName.NOTES);
    const noteRecord = noteData.find(data => data.cipher_id === cipherId);
    if (!noteRecord) {
      throw new Error(`Cipher secure note not found: ${cipherId}`);
    }
    const noteItem: CipherSecureNote = {
      type: noteRecord.type as CipherFieldType
    };
    return noteItem;
  }

  /**
   * 获取自定义字段
   */
  private async getCipherFields(cipherId: string): Promise<CipherField[]> {
    try {
      const fieldsData = await this.queryDetailRows(DBTableName.FIELDS);
      const fields: CipherField[] = [];

      for (const fieldData of fieldsData) {
        if (fieldData.cipher_id === cipherId) {
          const fieldName = await CryptoUtil.decryptField(fieldData.name as string, this.cipherKey);
          const fieldValue = await CryptoUtil.decryptField(fieldData.value as string, this.cipherKey);
          fields.push({
            name: fieldName,
            value: fieldValue,
            type: fieldData.type as CipherFieldType,
            linkedId: fieldData.linked_id == null ? null : fieldData.linked_id as number
          });
        }
      }

      return fields;
    } catch (error) {
      Logger.error(`Failed to get cipher fields: ${error}`);
      throw new Error(`Failed to decrypt cipher fields: ${error}`);
    }
  }

  /**
   * 更新密码项
   * @param cipher 要更新的密码项（包含明文数据）
   * @returns 更新后的密码项
   */
  async updateCipher(cipher: Cipher): Promise<Cipher> {
    try {
      if (!this.isCipherDecrypted) {
        throw new Error('cipher_not_decrypted');
      }
      // 构建加密的密码项
      const encryptedCipher = await this.buildEncryptedCipher(cipher);
      // 调用 API 更新
      const updatedCipher = await updateCipherApi(cipher.id, encryptedCipher);
      Logger.info('Cipher updated successfully');
      // 本地数据库只接收加密对象，当前界面继续保留原明文对象
      const cipherForDatabase = this.buildUpdatedEncryptedCipher(encryptedCipher, updatedCipher);
      await DatabaseUtil.getInstance().updateCipherToDatabase(cipherForDatabase);
      this.applyUpdatedCipherMetadata(cipher, cipherForDatabase);
      return cipher;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to update cipher: ${errorMessage}`);
      throw error as Error;
    }
  }

  /**
   * 更新收藏状态，该属性无需解密或重新加密密码项正文
   */
  async updateFavorite(cipher: Cipher, favorite: boolean): Promise<Cipher> {
    try {
      const updatedCipher = await updateCipherPartialApi(cipher.id, {
        folderId: cipher.folderId,
        favorite: favorite
      });
      const appliedFavorite = updatedCipher.favorite === undefined ? favorite : updatedCipher.favorite;
      let cipherData: relationalStore.ValuesBucket = {
        favorite: appliedFavorite ? 1 : 0
      };
      if (updatedCipher.revisionDate) {
        cipherData.revision_date = updatedCipher.revisionDate;
      }
      await DatabaseUtil.getInstance().updateData(DBTableName.MAIN, cipher.id, cipherData);
      cipher.favorite = appliedFavorite;
      if (updatedCipher.revisionDate) {
        cipher.revisionDate = updatedCipher.revisionDate;
        cipher.lastKnownRevisionDate = updatedCipher.revisionDate;
      }
      Logger.info('Cipher favorite updated successfully');
      return cipher;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to update cipher favorite: ${errorMessage}`);
      throw error as Error;
    }
  }

  private buildUpdatedEncryptedCipher(encryptedCipher: Cipher, updatedCipher: Cipher): Cipher {
    // 更新接口可能只回传部分字段，缺失值必须沿用本次提交的密文而非界面明文
    const revisionDate = updatedCipher.revisionDate || encryptedCipher.revisionDate;
    const reprompt = updatedCipher.reprompt === undefined || updatedCipher.reprompt === null
      ? encryptedCipher.reprompt
      : updatedCipher.reprompt;

    return {
      id: updatedCipher.id || encryptedCipher.id,
      type: updatedCipher.type || encryptedCipher.type,
      name: updatedCipher.name || encryptedCipher.name,
      favorite: updatedCipher.favorite === undefined ? encryptedCipher.favorite : updatedCipher.favorite,
      edit: updatedCipher.edit === undefined ? encryptedCipher.edit : updatedCipher.edit,
      folderId: updatedCipher.folderId === undefined ? encryptedCipher.folderId : updatedCipher.folderId,
      organizationId: updatedCipher.organizationId === undefined ? encryptedCipher.organizationId : updatedCipher.organizationId,
      creationDate: updatedCipher.creationDate || encryptedCipher.creationDate,
      revisionDate: revisionDate,
      lastKnownRevisionDate: revisionDate,
      deletedDate: updatedCipher.deletedDate === undefined ? encryptedCipher.deletedDate : updatedCipher.deletedDate,
      archivedDate: updatedCipher.archivedDate === undefined ? encryptedCipher.archivedDate || null : updatedCipher.archivedDate,
      notes: updatedCipher.notes === undefined ? encryptedCipher.notes : updatedCipher.notes,
      login: updatedCipher.login === undefined ? encryptedCipher.login : updatedCipher.login,
      card: updatedCipher.card === undefined ? encryptedCipher.card : updatedCipher.card,
      identity: updatedCipher.identity === undefined ? encryptedCipher.identity : updatedCipher.identity,
      secureNote: updatedCipher.secureNote === undefined ? encryptedCipher.secureNote : updatedCipher.secureNote,
      sshKey: updatedCipher.sshKey === undefined ? encryptedCipher.sshKey || null : updatedCipher.sshKey,
      bankAccount: updatedCipher.bankAccount === undefined ? encryptedCipher.bankAccount || null : updatedCipher.bankAccount,
      driversLicense: updatedCipher.driversLicense === undefined ? encryptedCipher.driversLicense || null :
        updatedCipher.driversLicense,
      passport: updatedCipher.passport === undefined ? encryptedCipher.passport || null : updatedCipher.passport,
      fields: updatedCipher.fields === undefined ? encryptedCipher.fields || [] : updatedCipher.fields,
      collectionIds: updatedCipher.collectionIds === undefined ? encryptedCipher.collectionIds || [] :
        updatedCipher.collectionIds,
      passwordHistory: updatedCipher.passwordHistory === undefined ? encryptedCipher.passwordHistory || null :
        updatedCipher.passwordHistory,
      attachments: updatedCipher.attachments === undefined ? encryptedCipher.attachments || null : updatedCipher.attachments,
      attachments2: updatedCipher.attachments2 === undefined ? encryptedCipher.attachments2 || null :
        updatedCipher.attachments2,
      key: updatedCipher.key === undefined ? encryptedCipher.key || null : updatedCipher.key,
      encryptedFor: updatedCipher.encryptedFor === undefined ? encryptedCipher.encryptedFor || null :
        updatedCipher.encryptedFor,
      reprompt: reprompt
    };
  }

  private applyUpdatedCipherMetadata(cipher: Cipher, updatedCipher: Cipher): void {
    cipher.lastKnownRevisionDate = updatedCipher.revisionDate;
    cipher.revisionDate = updatedCipher.revisionDate;
    if (updatedCipher.creationDate) {
      cipher.creationDate = updatedCipher.creationDate;
    }
    cipher.deletedDate = updatedCipher.deletedDate || null;
    cipher.archivedDate = updatedCipher.archivedDate || null;
    cipher.folderId = updatedCipher.folderId;
    cipher.organizationId = updatedCipher.organizationId;
    cipher.collectionIds = updatedCipher.collectionIds || cipher.collectionIds || [];
  }

  /**
   * 构建加密的密码项
   * @param cipher 明文密码项
   * @returns 加密后的密码项
   */
  private async buildEncryptedCipher(cipher: Cipher): Promise<Cipher> {
    // 参数 cipher 是界面编辑后的明文；返回值才允许发送到服务端或写入数据库
    this.cipherKey = await CryptoUtil.decryptCipherKey(cipher.key, this.symmetricKey);
    // 加密名称和备注
    const encName = await CryptoUtil.encryptField(cipher.name, this.cipherKey);
    const encNotes = cipher.notes && cipher.notes.trim().length > 0
      ? await CryptoUtil.encryptField(cipher.notes.trim(), this.cipherKey)
      : null;
    const timestamp = DeviceUtil.getISOTimestamp();

    // 构建加密后的密码项
    const encryptedCipher: Cipher = {
      id: cipher.id,
      type: cipher.type,
      name: encName,
      favorite: cipher.favorite,
      edit: cipher.edit,
      folderId: cipher.folderId,
      organizationId: cipher.organizationId,
      creationDate: cipher.creationDate,
      revisionDate: timestamp,
      lastKnownRevisionDate: cipher.lastKnownRevisionDate || cipher.revisionDate,
      deletedDate: cipher.deletedDate,
      archivedDate: cipher.archivedDate || null,
      notes: encNotes,
      login: null,
      card: null,
      identity: null,
      secureNote: null,
      sshKey: cipher.sshKey || null,
      bankAccount: cipher.bankAccount || null,
      driversLicense: cipher.driversLicense || null,
      passport: cipher.passport || null,
      fields: cipher.fields || [],
      collectionIds: cipher.collectionIds || [],
      passwordHistory: cipher.passwordHistory || null,
      attachments: cipher.attachments || null,
      attachments2: cipher.attachments2 || null,
      key: cipher.key || null,
      encryptedFor: cipher.encryptedFor || null,
      reprompt: cipher.reprompt
    };

    // 根据类型加密详细信息
    switch (cipher.type) {
      case CipherItemType.LOGIN:
        encryptedCipher.login = await this.buildEncryptedLogin(cipher.login);
        break;
      case CipherItemType.CARD:
        encryptedCipher.card = await this.buildEncryptedCard(cipher.card);
        break;
      case CipherItemType.IDENTITY:
        encryptedCipher.identity = await this.buildEncryptedIdentity(cipher.identity);
        break;
      case CipherItemType.NOTE:
        encryptedCipher.secureNote = cipher.secureNote;
        break;
    }

    // 加密自定义字段
    if (cipher.fields && cipher.fields.length > 0) {
      encryptedCipher.fields = await this.buildEncryptedFields(cipher.fields);
    }

    return encryptedCipher;
  }

  /**
   * 构建加密的登录信息
   */
  private async buildEncryptedLogin(login: CipherLogin | null): Promise<CipherLogin> {
    if (!login) {
      return {} as CipherLogin;
    }

    const encUsername = login.username ? await CryptoUtil.encryptField(login.username, this.cipherKey) : null;
    const encPassword = login.password ? await CryptoUtil.encryptField(login.password, this.cipherKey) : null;
    const encTotp = login.totp ? await CryptoUtil.encryptField(login.totp, this.cipherKey) : null;

    let encUris: CipherUri[] = [];
    if (login.uris && login.uris.length > 0) {
      encUris = await Promise.all(login.uris.map(async (uri) => {
        const plainUri = uri.uri ? uri.uri.trim() : '';
        const encUri = plainUri ? await CryptoUtil.encryptField(plainUri, this.cipherKey) : '';
        const sha256CheckSum = plainUri ? await CryptoUtil.doSha256(plainUri) : '';
        const encChecksum = sha256CheckSum ? await CryptoUtil.encryptField(sha256CheckSum, this.cipherKey) : '';
        const cipherUri: CipherUri = {
          uri: encUri,
          uriChecksum: encChecksum,
          match: uri.match ?? null
        };
        return cipherUri;
      }));
    }

    return {
      username: encUsername,
      password: encPassword,
      passwordRevisionDate: login.passwordRevisionDate,
      totp: encTotp,
      uris: encUris,
      uri: login.uri ? await CryptoUtil.encryptField(login.uri, this.cipherKey) : null,
      autofillOnPageLoad: login.autofillOnPageLoad ?? null,
      fido2Credentials: login.fido2Credentials || null
    };
  }

  /**
   * 构建加密的卡片信息
   */
  private async buildEncryptedCard(card: CipherCard | null): Promise<CipherCard> {
    if (!card) {
      return {} as CipherCard;
    }

    const encCardholderName =
      card.cardholderName ? await CryptoUtil.encryptField(card.cardholderName, this.cipherKey) : null;
    const encBrand = card.brand ? await CryptoUtil.encryptField(card.brand, this.cipherKey) : null;
    const encNumber = card.number ? await CryptoUtil.encryptField(card.number, this.cipherKey) : null;
    const encExpMonth = card.expMonth ? await CryptoUtil.encryptField(card.expMonth, this.cipherKey) : null;
    const encExpYear = card.expYear ? await CryptoUtil.encryptField(card.expYear, this.cipherKey) : null;
    const encCode = card.code ? await CryptoUtil.encryptField(card.code, this.cipherKey) : null;

    return {
      cardholderName: encCardholderName,
      brand: encBrand,
      number: encNumber,
      expMonth: encExpMonth,
      expYear: encExpYear,
      code: encCode
    };
  }

  /**
   * 构建加密的身份信息
   */
  private async buildEncryptedIdentity(identity: CipherIdentity | null): Promise<CipherIdentity> {
    if (!identity) {
      return {} as CipherIdentity;
    }

    const encTitle = identity.title ? await CryptoUtil.encryptField(identity.title, this.cipherKey) : null;
    const encFirstName = identity.firstName ? await CryptoUtil.encryptField(identity.firstName, this.cipherKey) : null;
    const encMiddleName =
      identity.middleName ? await CryptoUtil.encryptField(identity.middleName, this.cipherKey) : null;
    const encLastName = identity.lastName ? await CryptoUtil.encryptField(identity.lastName, this.cipherKey) : null;
    const encAddress1 = identity.address1 ? await CryptoUtil.encryptField(identity.address1, this.cipherKey) : null;
    const encAddress2 = identity.address2 ? await CryptoUtil.encryptField(identity.address2, this.cipherKey) : null;
    const encAddress3 = identity.address3 ? await CryptoUtil.encryptField(identity.address3, this.cipherKey) : null;
    const encCity = identity.city ? await CryptoUtil.encryptField(identity.city, this.cipherKey) : null;
    const encState = identity.state ? await CryptoUtil.encryptField(identity.state, this.cipherKey) : null;
    const encPostalCode =
      identity.postalCode ? await CryptoUtil.encryptField(identity.postalCode, this.cipherKey) : null;
    const encCountry = identity.country ? await CryptoUtil.encryptField(identity.country, this.cipherKey) : null;
    const encCompany = identity.company ? await CryptoUtil.encryptField(identity.company, this.cipherKey) : null;
    const encEmail = identity.email ? await CryptoUtil.encryptField(identity.email, this.cipherKey) : null;
    const encPhone = identity.phone ? await CryptoUtil.encryptField(identity.phone, this.cipherKey) : null;
    const encSSN = identity.ssn ? await CryptoUtil.encryptField(identity.ssn, this.cipherKey) : null;
    const encLicenseNumber =
      identity.licenseNumber ? await CryptoUtil.encryptField(identity.licenseNumber, this.cipherKey) : null;
    const encPassportNumber =
      identity.passportNumber ? await CryptoUtil.encryptField(identity.passportNumber, this.cipherKey) : null;
    const encUsername = identity.username ? await CryptoUtil.encryptField(identity.username, this.cipherKey) : null;

    return {
      title: encTitle,
      firstName: encFirstName,
      middleName: encMiddleName,
      lastName: encLastName,
      address1: encAddress1,
      address2: encAddress2,
      address3: encAddress3,
      city: encCity,
      state: encState,
      postalCode: encPostalCode,
      country: encCountry,
      company: encCompany,
      email: encEmail,
      phone: encPhone,
      ssn: encSSN,
      licenseNumber: encLicenseNumber,
      passportNumber: encPassportNumber,
      username: encUsername
    };
  }

  /**
   * 构建加密的自定义字段
   */
  private async buildEncryptedFields(fields: CipherField[]): Promise<CipherField[]> {
    return await Promise.all(fields.map(async (field) => {
      const encName = field.name ? await CryptoUtil.encryptField(field.name, this.cipherKey) : '';
      const encValue = field.value ? await CryptoUtil.encryptField(field.value, this.cipherKey) : '';
      const cipherField: CipherField = {
        name: encName,
        value: encValue,
        type: field.type,
        linkedId: field.linkedId ?? null
      };
      return cipherField;
    }));
  }

  /**
   * 删除密码项
   * @param cipher 要删除的密码项
   */
  async deleteCipher(cipher: Cipher, isRealDelete: boolean): Promise<Cipher | null> {
    try {
      // 确认是否彻底删除
      if (isRealDelete) {
        await deleteCipher(cipher.id);
        Logger.info('Cipher deleted successfully from server');

        // 从本地数据库删除
        await this.deleteFromLocalDatabase(cipher.id);
        Logger.info('Cipher deleted from local database');
        return null;
      }

      await moveCipherToRecycler(cipher.id);
      const deletedDate = DeviceUtil.getISOTimestamp();
      await this.updateSoftDeletedCipherInLocalDatabase(cipher.id, deletedDate);
      cipher.deletedDate = deletedDate;
      return cipher;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to delete cipher: ${errorMessage}`);
      throw error as Error;
    }
  }

  private async updateSoftDeletedCipherInLocalDatabase(cipherId: string, deletedDate: string): Promise<void> {
    const cipherData: relationalStore.ValuesBucket = {
      deleted_date: deletedDate
    };
    await DatabaseUtil.getInstance().updateData(DBTableName.MAIN, cipherId, cipherData);
  }

  /**
   * 从本地数据库删除密码项
   * @param cipherId 密码项ID
   */
  private async deleteFromLocalDatabase(cipherId: string): Promise<void> {
    try {
      const escapedCipherId = cipherId.replace(/'/g, "''");
      // executeSql 无绑定参数接口，此处先转义引号以守住 SQL 文本边界
      await DatabaseUtil.getInstance().executeSql(
        `DELETE FROM ${DBTableName.KEYS} WHERE cipher_id = '${escapedCipherId}'`
      );
      // 从主表删除
      await DatabaseUtil.getInstance().deleteData(DBTableName.MAIN, cipherId);

      // 根据类型从详细信息表删除
      const loginId = `${cipherId}_login`;
      const cardId = `${cipherId}_card`;
      const identityId = `${cipherId}_identity`;
      const noteId = `${cipherId}_note`;

      // 尝试从各个表中删除（静默失败，因为可能不存在）
      try {
        await DatabaseUtil.getInstance().deleteData(DBTableName.LOGINS, loginId);
      } catch (e) {
        // 忽略错误
      }
      try {
        await DatabaseUtil.getInstance().deleteData(DBTableName.CARDS, cardId);
      } catch (e) {
        // 忽略错误
      }
      try {
        await DatabaseUtil.getInstance().deleteData(DBTableName.IDENTITIES, identityId);
      } catch (e) {
        // 忽略错误
      }
      try {
        await DatabaseUtil.getInstance().deleteData(DBTableName.NOTES, noteId);
      } catch (e) {
        // 忽略错误
      }

      // 删除自定义字段
      const fieldsData = await DatabaseUtil.getInstance().queryAllData(DBTableName.FIELDS);
      for (const fieldData of fieldsData) {
        if (fieldData.cipher_id === cipherId) {
          try {
            await DatabaseUtil.getInstance().deleteData(DBTableName.FIELDS, fieldData.id as string);
          } catch (e) {
            // 忽略错误
          }
        }
      }

      Logger.info('Local database cleanup completed for cipher');
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to delete from local database: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /**
   * 还原密码项
   * @param cipher 要还原的密码项（包含明文数据）
   * @returns 更新后的密码项
   */
  async restoreCipher(cipher: Cipher): Promise<Cipher> {
    try {
      // 调用 API 还原
      const restoredCipher = await restoreCipher(cipher.id);
      Logger.info('Cipher restored successfully');

      await this.updateRestoredCipherInLocalDatabase(cipher.id, restoredCipher.revisionDate || null);
      this.applyRestoredCipherMetadata(cipher, restoredCipher);
      return cipher;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to restore cipher: ${errorMessage}`);
      throw error as Error;
    }
  }

  private async updateRestoredCipherInLocalDatabase(cipherId: string, revisionDate: string | null): Promise<void> {
    const cipherData: relationalStore.ValuesBucket = {
      deleted_date: null
    };
    if (revisionDate) {
      cipherData.revision_date = revisionDate;
    }
    await DatabaseUtil.getInstance().updateData(DBTableName.MAIN, cipherId, cipherData);
  }

  private applyRestoredCipherMetadata(cipher: Cipher, restoredCipher: Cipher): void {
    cipher.deletedDate = null;
    if (restoredCipher.revisionDate) {
      cipher.lastKnownRevisionDate = restoredCipher.revisionDate;
      cipher.revisionDate = restoredCipher.revisionDate;
    }
    if (restoredCipher.creationDate) {
      cipher.creationDate = restoredCipher.creationDate;
    }
    cipher.archivedDate = restoredCipher.archivedDate === undefined ? cipher.archivedDate || null : restoredCipher.archivedDate;
    cipher.folderId = restoredCipher.folderId === undefined ? cipher.folderId : restoredCipher.folderId;
    cipher.organizationId = restoredCipher.organizationId === undefined ? cipher.organizationId : restoredCipher.organizationId;
    cipher.collectionIds = restoredCipher.collectionIds || cipher.collectionIds || [];
  }
}
