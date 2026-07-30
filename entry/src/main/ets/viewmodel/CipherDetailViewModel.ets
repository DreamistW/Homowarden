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
  updateCipher as updateCipherApi
} from '../network/CipherApi';
import { DeviceUtil } from '../utils/DeviceUtil';
import { relationalStore } from '@kit.ArkData';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

/** 负责密码项详情解密、协议加密以及更新、删除、回收和还原的远端/本地协调。 */
export class CipherDetailViewModel {
  /** 页面注入的 Base64 对称密钥；传入和返回的详情对象包含明文业务字段。 */
  symmetricKey: string = '';
  private cipherKey: string = '';
  private isCipherDecrypted: boolean = false;

  /**
   * 从类型子表读取并解密详情，同时附加自定义字段。
   * @throws 对应类型记录缺失、数据库查询或字段解密失败时传播异常；自定义字段失败单独降级为空数组。
   */
  async getCipherDetail(cipher: Cipher): Promise<Cipher> {
    this.isCipherDecrypted = false;
    this.cipherKey = await CryptoUtil.decryptCipherKey(cipher.key, this.symmetricKey);
    // 根据类型获取详细信息
    switch (cipher.type) {
      case CipherItemType.LOGIN: // LOGIN
        cipher.login = await this.getCipherLogin(cipher.id);
        break;
      case CipherItemType.NOTE: // NOTE
        cipher.secureNote = await this.getCipherSecureNote(cipher.id);
        break;
      case CipherItemType.CARD: // CARD
        cipher.card = await this.getCipherCard(cipher.id);
        break;
      case CipherItemType.IDENTITY: // IDENTITY
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
    const loginData = await DatabaseUtil.getInstance().queryAllData(DBTableName.LOGINS);
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

  /** 原地解密 URI 与校验和数组；任一字段解密失败时传播异常。 */
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
    const cardData = await DatabaseUtil.getInstance().queryAllData(DBTableName.CARDS);
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
    const identityData = await DatabaseUtil.getInstance().queryAllData(DBTableName.IDENTITIES);
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
    const noteData = await DatabaseUtil.getInstance().queryAllData(DBTableName.NOTES);
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
      const fieldsData = await DatabaseUtil.getInstance().queryAllData(DBTableName.FIELDS);
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
      Logger.error(`Failed to get fields for cipher ${cipherId}: ${error}`);
      throw new Error(`Failed to decrypt cipher fields: ${error}`);
    }
  }

  /**
   * 更新密码项
   * @param cipher 要更新的密码项（包含明文数据）
   * @returns 原明文对象，其服务端修订及归属元数据已原地更新。
   * @throws 加密、网络或本地缓存异常会转换为只含可展示消息的新 Error。
   */
  async updateCipher(cipher: Cipher): Promise<Cipher> {
    try {
      if (!this.isCipherDecrypted) {
        throw new Error('密码项尚未成功解密，禁止保存');
      }
      // 构建加密的密码项
      const encryptedCipher = await this.buildEncryptedCipher(cipher);
      // 调用 API 更新
      const updatedCipher = await updateCipherApi(cipher.id, encryptedCipher);
      Logger.info(`Cipher ${cipher.id} updated successfully`);
      // 将更新的密码项写入数据库
      const cipherForDatabase = this.buildUpdatedEncryptedCipher(encryptedCipher, updatedCipher);
      await DatabaseUtil.getInstance().updateCipherToDatabase(cipherForDatabase);
      this.applyUpdatedCipherMetadata(cipher, cipherForDatabase);
      return cipher;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to update cipher ${cipher.id}: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /** 合并服务端部分响应与已提交密文，形成可完整写入本地缓存的对象。 */
  private buildUpdatedEncryptedCipher(encryptedCipher: Cipher, updatedCipher: Cipher): Cipher {
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
    cipher.revisionDate = this.formatDateTime(updatedCipher.revisionDate);
    if (updatedCipher.creationDate) {
      cipher.creationDate = this.formatDateTime(updatedCipher.creationDate);
    }
    cipher.deletedDate = updatedCipher.deletedDate ? this.formatDateTime(updatedCipher.deletedDate) : null;
    cipher.archivedDate = updatedCipher.archivedDate || null;
    cipher.folderId = updatedCipher.folderId;
    cipher.organizationId = updatedCipher.organizationId;
    cipher.collectionIds = updatedCipher.collectionIds || cipher.collectionIds || [];
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

  /**
   * 构建加密的密码项
   * @param cipher 明文密码项
   * @returns 保留协议元数据、敏感业务字段已加密的密码项。
   * @throws 任一字段加密或校验和计算失败时传播异常。
   */
  private async buildEncryptedCipher(cipher: Cipher): Promise<Cipher> {
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

    const encUsername = login.username ? await CryptoUtil.encryptField(login.username, this.cipherKey) : '';
    const encPassword = login.password ? await CryptoUtil.encryptField(login.password, this.cipherKey) : '';
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
      card.cardholderName ? await CryptoUtil.encryptField(card.cardholderName, this.cipherKey) : '';
    const encBrand = card.brand ? await CryptoUtil.encryptField(card.brand, this.cipherKey) : '';
    const encNumber = card.number ? await CryptoUtil.encryptField(card.number, this.cipherKey) : '';
    const encExpMonth = card.expMonth ? await CryptoUtil.encryptField(card.expMonth, this.cipherKey) : '';
    const encExpYear = card.expYear ? await CryptoUtil.encryptField(card.expYear, this.cipherKey) : '';
    const encCode = card.code ? await CryptoUtil.encryptField(card.code, this.cipherKey) : '';

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

    const encTitle = identity.title ? await CryptoUtil.encryptField(identity.title, this.cipherKey) : '';
    const encFirstName = identity.firstName ? await CryptoUtil.encryptField(identity.firstName, this.cipherKey) : '';
    const encMiddleName =
      identity.middleName ? await CryptoUtil.encryptField(identity.middleName, this.cipherKey) : '';
    const encLastName = identity.lastName ? await CryptoUtil.encryptField(identity.lastName, this.cipherKey) : '';
    const encAddress1 = identity.address1 ? await CryptoUtil.encryptField(identity.address1, this.cipherKey) : '';
    const encAddress2 = identity.address2 ? await CryptoUtil.encryptField(identity.address2, this.cipherKey) : '';
    const encAddress3 = identity.address3 ? await CryptoUtil.encryptField(identity.address3, this.cipherKey) : '';
    const encCity = identity.city ? await CryptoUtil.encryptField(identity.city, this.cipherKey) : '';
    const encState = identity.state ? await CryptoUtil.encryptField(identity.state, this.cipherKey) : '';
    const encPostalCode =
      identity.postalCode ? await CryptoUtil.encryptField(identity.postalCode, this.cipherKey) : '';
    const encCountry = identity.country ? await CryptoUtil.encryptField(identity.country, this.cipherKey) : '';
    const encCompany = identity.company ? await CryptoUtil.encryptField(identity.company, this.cipherKey) : '';
    const encEmail = identity.email ? await CryptoUtil.encryptField(identity.email, this.cipherKey) : '';
    const encPhone = identity.phone ? await CryptoUtil.encryptField(identity.phone, this.cipherKey) : '';
    const encSSN = identity.ssn ? await CryptoUtil.encryptField(identity.ssn, this.cipherKey) : '';
    const encLicenseNumber =
      identity.licenseNumber ? await CryptoUtil.encryptField(identity.licenseNumber, this.cipherKey) : '';
    const encPassportNumber =
      identity.passportNumber ? await CryptoUtil.encryptField(identity.passportNumber, this.cipherKey) : '';
    const encUsername = identity.username ? await CryptoUtil.encryptField(identity.username, this.cipherKey) : '';

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
   * @param cipher 当前明文密码项，软删除时会原地更新删除时间。
   * @param isRealDelete `true` 时远端及本地彻底删除；否则移入回收站。
   * @returns 软删除后的原对象；彻底删除成功时返回 `null`。
   * @throws 网络或关键本地数据库操作失败时转换为可展示消息 Error。
   */
  async deleteCipher(cipher: Cipher, isRealDelete: boolean): Promise<Cipher | null> {
    try {
      // 确认是否彻底删除
      if (isRealDelete) {
        await deleteCipher(cipher.id);
        Logger.info(`Cipher ${cipher.id} deleted successfully from server`);

        // 从本地数据库删除
        await this.deleteFromLocalDatabase(cipher.id);
        Logger.info(`Cipher ${cipher.id} deleted from local database`);
        return null;
      }

      await moveCipherToRecycler(cipher.id);
      const deletedDate = DeviceUtil.getISOTimestamp();
      await this.updateSoftDeletedCipherInLocalDatabase(cipher.id, deletedDate);
      cipher.deletedDate = this.formatDateTime(deletedDate);
      return cipher;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to delete cipher ${cipher.id}: ${errorMessage}`);
      throw new Error(errorMessage);
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

      Logger.info(`Local database cleanup completed for cipher ${cipherId}`);
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to delete from local database: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /**
   * 还原密码项
   * @param cipher 要还原的密码项（包含明文数据）
   * @returns 原明文对象，其删除时间及服务端元数据已原地更新。
   * @throws 网络或本地缓存失败时转换为可展示消息 Error。
   */
  async restoreCipher(cipher: Cipher): Promise<Cipher> {
    try {
      // 调用 API 还原
      const restoredCipher = await restoreCipher(cipher.id);
      Logger.info(`Cipher ${cipher.id} restored successfully`);

      await this.updateRestoredCipherInLocalDatabase(cipher.id, restoredCipher.revisionDate || null);
      this.applyRestoredCipherMetadata(cipher, restoredCipher);
      return cipher;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to restore cipher ${cipher.id}: ${errorMessage}`);
      throw new Error(errorMessage);
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
      cipher.revisionDate = this.formatDateTime(restoredCipher.revisionDate);
    }
    if (restoredCipher.creationDate) {
      cipher.creationDate = this.formatDateTime(restoredCipher.creationDate);
    }
    cipher.archivedDate = restoredCipher.archivedDate === undefined ? cipher.archivedDate || null : restoredCipher.archivedDate;
    cipher.folderId = restoredCipher.folderId === undefined ? cipher.folderId : restoredCipher.folderId;
    cipher.organizationId = restoredCipher.organizationId === undefined ? cipher.organizationId : restoredCipher.organizationId;
    cipher.collectionIds = restoredCipher.collectionIds || cipher.collectionIds || [];
  }
}
