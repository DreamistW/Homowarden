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

export class CipherDetailViewModel {
  symmetricKey: string = '';

  /**
   * 获取完整的密码项详情
   */
  async getCipherDetail(cipher: Cipher): Promise<Cipher> {
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
    return cipher;
  }

  /**
   * 获取登录信息
   */
  private async getCipherLogin(cipherId: string): Promise<CipherLogin> {
    return new Promise(async (resolve, reject) => {
      const loginData = await DatabaseUtil.getInstance().queryAllData(DBTableName.LOGINS);
      const loginRecord = loginData.find(data => data.cipher_id === cipherId);

      if (loginRecord) {
        const username = await CryptoUtil.decryptField(loginRecord.username as string, this.symmetricKey);
        const password = await CryptoUtil.decryptField(loginRecord.password as string, this.symmetricKey);
        const totp = await CryptoUtil.decryptField(loginRecord.totp as string, this.symmetricKey);
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
        resolve(loginItem);
      } else {
        reject();
      }
    })
  }

  // 解析URI数组
  async parseUris(uris: CipherUri[]): Promise<CipherUri[]> {
    return await Promise.all(
      uris.map(async (item: CipherUri) => {
        item.uri = await CryptoUtil.decryptField(item.uri, this.symmetricKey);
        item.uriChecksum = await CryptoUtil.decryptField(item.uriChecksum, this.symmetricKey);
        return item;
      })
    );
  }

  /**
   * 获取卡片信息
   */
  private async getCipherCard(cipherId: string): Promise<CipherCard> {
    return new Promise(async (resolve, reject) => {
      const cardData = await DatabaseUtil.getInstance().queryAllData(DBTableName.CARDS);
      const cardRecord = cardData.find(data => data.cipher_id === cipherId);

      if (cardRecord) {
        const cardholderName = await CryptoUtil.decryptField(cardRecord.cardholder_name as string, this.symmetricKey);
        const brand = await CryptoUtil.decryptField(cardRecord.brand as string, this.symmetricKey);
        const number = await CryptoUtil.decryptField(cardRecord.number as string, this.symmetricKey);
        const expMonth = await CryptoUtil.decryptField(cardRecord.exp_month as string, this.symmetricKey);
        const expYear = await CryptoUtil.decryptField(cardRecord.exp_year as string, this.symmetricKey);
        const code = await CryptoUtil.decryptField(cardRecord.code as string, this.symmetricKey);
        const cardItem: CipherCard = {
          cardholderName: cardholderName,
          brand: brand,
          number: number,
          expMonth: expMonth,
          expYear: expYear,
          code: code
        };
        resolve(cardItem);
      } else {
        reject();
      }
    })
  }

  /**
   * 获取身份信息
   */
  private async getCipherIdentity(cipherId: string): Promise<CipherIdentity> {
    return new Promise(async (resolve, reject) => {
      const identityData = await DatabaseUtil.getInstance().queryAllData(DBTableName.IDENTITIES);
      const identityRecord = identityData.find(data => data.cipher_id === cipherId);

      if (identityRecord) {
        const address1 = await CryptoUtil.decryptField(identityRecord.address1 as string, this.symmetricKey);
        const address2 = await CryptoUtil.decryptField(identityRecord.address2 as string, this.symmetricKey);
        const address3 = await CryptoUtil.decryptField(identityRecord.address3 as string, this.symmetricKey);
        const city = await CryptoUtil.decryptField(identityRecord.city as string, this.symmetricKey);
        const company = await CryptoUtil.decryptField(identityRecord.company as string, this.symmetricKey);
        const country = await CryptoUtil.decryptField(identityRecord.country as string, this.symmetricKey);
        const email = await CryptoUtil.decryptField(identityRecord.email as string, this.symmetricKey);
        const firstName = await CryptoUtil.decryptField(identityRecord.first_name as string, this.symmetricKey);
        const lastName = await CryptoUtil.decryptField(identityRecord.last_name as string, this.symmetricKey);
        const licenseNumber = await CryptoUtil.decryptField(identityRecord.license_number as string, this.symmetricKey);
        const middleName = await CryptoUtil.decryptField(identityRecord.middle_name as string, this.symmetricKey);
        const passportNumber =
          await CryptoUtil.decryptField(identityRecord.passport_number as string, this.symmetricKey);
        const phone = await CryptoUtil.decryptField(identityRecord.phone as string, this.symmetricKey);
        const postalCode = await CryptoUtil.decryptField(identityRecord.postal_code as string, this.symmetricKey);
        const ssn = await CryptoUtil.decryptField(identityRecord.ssn as string, this.symmetricKey);
        const state = await CryptoUtil.decryptField(identityRecord.state as string, this.symmetricKey);
        const title = await CryptoUtil.decryptField(identityRecord.title as string, this.symmetricKey);
        const username = await CryptoUtil.decryptField(identityRecord.username as string, this.symmetricKey);
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
        resolve(identityItem);
      } else {
        reject();
      }
    })
  }

  /**
   * 获取安全笔记
   */
  private async getCipherSecureNote(cipherId: string): Promise<CipherSecureNote> {
    return new Promise(async (resolve, reject) => {
      const noteData = await DatabaseUtil.getInstance().queryAllData(DBTableName.NOTES);
      const noteRecord = noteData.find(data => data.cipher_id === cipherId);

      if (noteRecord) {
        const noteItem: CipherSecureNote = {
          type: noteRecord.type as CipherFieldType
        };
        resolve(noteItem);
      } else {
        reject();
      }
    })
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
          const fieldName = await CryptoUtil.decryptField(fieldData.name as string, this.symmetricKey);
          const fieldValue = await CryptoUtil.decryptField(fieldData.value as string, this.symmetricKey);
          fields.push({
            name: fieldName,
            value: fieldValue,
            type: fieldData.type as CipherFieldType
          });
        }
      }

      return fields;
    } catch (error) {
      Logger.error(`Failed to get fields for cipher ${cipherId}: ${error}`);
      return [];
    }
  }

  /**
   * 更新密码项
   * @param cipher 要更新的密码项（包含明文数据）
   * @returns 更新后的密码项
   */
  async updateCipher(cipher: Cipher): Promise<Cipher> {
    try {
      // 构建加密的密码项
      const encryptedCipher = await this.buildEncryptedCipher(cipher);
      // 调用 API 更新
      const updatedCipher = await updateCipherApi(cipher.id, encryptedCipher);
      Logger.info(`Cipher ${cipher.id} updated successfully`);
      return updatedCipher;
    } catch (error) {
      Logger.error(`Failed to update cipher ${cipher.id}: ${error}`);
      throw new Error(`Failed to update cipher: ${error}`);
    }
  }

  /**
   * 构建加密的密码项
   * @param cipher 明文密码项
   * @returns 加密后的密码项
   */
  private async buildEncryptedCipher(cipher: Cipher): Promise<Cipher> {
    // 加密名称和备注
    const encName = await CryptoUtil.encryptField(cipher.name, this.symmetricKey);
    const encNotes = cipher.notes && cipher.notes.trim().length > 0
      ? await CryptoUtil.encryptField(cipher.notes.trim(), this.symmetricKey)
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
      deletedDate: cipher.deletedDate,
      notes: encNotes,
      login: null,
      card: null,
      identity: null,
      secureNote: null,
      fields: cipher.fields || [],
      collectionIds: cipher.collectionIds || [],
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

    const encUsername = login.username ? await CryptoUtil.encryptField(login.username, this.symmetricKey) : '';
    const encPassword = login.password ? await CryptoUtil.encryptField(login.password, this.symmetricKey) : '';
    const encTotp = login.totp ? await CryptoUtil.encryptField(login.totp, this.symmetricKey) : null;

    let encUris: CipherUri[] = [];
    if (login.uris && login.uris.length > 0) {
      encUris = await Promise.all(login.uris.map(async (uri) => {
        const encUri = uri.uri ? await CryptoUtil.encryptField(uri.uri, this.symmetricKey) : '';
        const encChecksum = uri.uriChecksum ? await CryptoUtil.encryptField(uri.uriChecksum, this.symmetricKey) : '';
        const cipherUri: CipherUri = {
          uri: encUri,
          uriChecksum: encChecksum
        };
        return cipherUri;
      }));
    }

    return {
      username: encUsername,
      password: encPassword,
      passwordRevisionDate: login.passwordRevisionDate,
      totp: encTotp,
      uris: encUris
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
      card.cardholderName ? await CryptoUtil.encryptField(card.cardholderName, this.symmetricKey) : '';
    const encBrand = card.brand ? await CryptoUtil.encryptField(card.brand, this.symmetricKey) : '';
    const encNumber = card.number ? await CryptoUtil.encryptField(card.number, this.symmetricKey) : '';
    const encExpMonth = card.expMonth ? await CryptoUtil.encryptField(card.expMonth, this.symmetricKey) : '';
    const encExpYear = card.expYear ? await CryptoUtil.encryptField(card.expYear, this.symmetricKey) : '';
    const encCode = card.code ? await CryptoUtil.encryptField(card.code, this.symmetricKey) : '';

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

    const encTitle = identity.title ? await CryptoUtil.encryptField(identity.title, this.symmetricKey) : '';
    const encFirstName = identity.firstName ? await CryptoUtil.encryptField(identity.firstName, this.symmetricKey) : '';
    const encMiddleName =
      identity.middleName ? await CryptoUtil.encryptField(identity.middleName, this.symmetricKey) : '';
    const encLastName = identity.lastName ? await CryptoUtil.encryptField(identity.lastName, this.symmetricKey) : '';
    const encAddress1 = identity.address1 ? await CryptoUtil.encryptField(identity.address1, this.symmetricKey) : '';
    const encAddress2 = identity.address2 ? await CryptoUtil.encryptField(identity.address2, this.symmetricKey) : '';
    const encAddress3 = identity.address3 ? await CryptoUtil.encryptField(identity.address3, this.symmetricKey) : '';
    const encCity = identity.city ? await CryptoUtil.encryptField(identity.city, this.symmetricKey) : '';
    const encState = identity.state ? await CryptoUtil.encryptField(identity.state, this.symmetricKey) : '';
    const encPostalCode =
      identity.postalCode ? await CryptoUtil.encryptField(identity.postalCode, this.symmetricKey) : '';
    const encCountry = identity.country ? await CryptoUtil.encryptField(identity.country, this.symmetricKey) : '';
    const encCompany = identity.company ? await CryptoUtil.encryptField(identity.company, this.symmetricKey) : '';
    const encEmail = identity.email ? await CryptoUtil.encryptField(identity.email, this.symmetricKey) : '';
    const encPhone = identity.phone ? await CryptoUtil.encryptField(identity.phone, this.symmetricKey) : '';
    const encSSN = identity.ssn ? await CryptoUtil.encryptField(identity.ssn, this.symmetricKey) : '';
    const encLicenseNumber =
      identity.licenseNumber ? await CryptoUtil.encryptField(identity.licenseNumber, this.symmetricKey) : '';
    const encPassportNumber =
      identity.passportNumber ? await CryptoUtil.encryptField(identity.passportNumber, this.symmetricKey) : '';
    const encUsername = identity.username ? await CryptoUtil.encryptField(identity.username, this.symmetricKey) : '';

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
      const encName = field.name ? await CryptoUtil.encryptField(field.name, this.symmetricKey) : '';
      const encValue = field.value ? await CryptoUtil.encryptField(field.value, this.symmetricKey) : '';
      const cipherField: CipherField = {
        name: encName,
        value: encValue,
        type: field.type
      };
      return cipherField;
    }));
  }

  /**
   * 删除密码项
   * @param cipherId 要删除的密码项ID
   */
  async deleteCipher(cipherId: string, isRealDelete: boolean): Promise<void> {
    try {
      // 确认是否彻底删除
      if (isRealDelete) {
        await deleteCipher(cipherId);
        Logger.info(`Cipher ${cipherId} deleted successfully from server`);

        // 从本地数据库删除
        await this.deleteFromLocalDatabase(cipherId);
        Logger.info(`Cipher ${cipherId} deleted from local database`);
      } else {
        await moveCipherToRecycler(cipherId);
      }
    } catch (error) {
      Logger.error(`Failed to delete cipher ${cipherId}: ${error}`);
      throw new Error(`Failed to delete cipher: ${error}`);
    }
  }

  /**
   * 从本地数据库删除密码项
   * @param cipherId 密码项ID
   */
  private async deleteFromLocalDatabase(cipherId: string): Promise<void> {
    try {
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
      Logger.error(`Failed to delete from local database: ${error}`);
      throw new Error(`Failed to delete cipher from local database: ${error}`);
    }
  }

  /**
   * 还原密码项
   * @param cipher 要还原的密码项（包含明文数据）
   * @returns 更新后的密码项
   */
  async restoreCipher(cipher: Cipher): Promise<Cipher> {
    try {
      // 构建加密的密码项
      const encryptedCipher = await this.buildEncryptedCipher(cipher);
      // 调用 API 还原
      const restoredCipher = await restoreCipher(cipher.id, encryptedCipher);
      Logger.info(`Cipher ${cipher.id} restored successfully`);
      return restoredCipher;
    } catch (error) {
      Logger.error(`Failed to restore cipher ${cipher.id}: ${error}`);
      throw new Error(`Failed to restore cipher: ${error}`);
    }
  }
}