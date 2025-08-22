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
}