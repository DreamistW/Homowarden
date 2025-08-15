import { Logger } from '@nzy/logger';
import { Cipher, CipherCard, CipherField, CipherIdentity, CipherLogin, CipherSecureNote } from '../model/CipherModels';
import { CipherFieldType, CipherItemType, DBTableName } from '../utils/Constants';
import { DatabaseUtil } from '../utils/DatabaseUtil';

export class CipherDetailViewModel {
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
        const loginItem: CipherLogin = {
          username: loginRecord.username as string || '',
          password: loginRecord.password as string || '',
          passwordRevisionDate: loginRecord.password_revision_date as string || null,
          totp: loginRecord.totp as string || null,
          uris: loginRecord.uris ? JSON.parse(loginRecord.uris as string) : undefined
        };
        resolve(loginItem);
      } else {
        reject();
      }
    })
  }

  /**
   * 获取卡片信息
   */
  private async getCipherCard(cipherId: string): Promise<CipherCard> {
    return new Promise(async (resolve, reject) => {
      const cardData = await DatabaseUtil.getInstance().queryAllData(DBTableName.CARDS);
      const cardRecord = cardData.find(data => data.cipher_id === cipherId);

      if (cardRecord) {
        const cardItem: CipherCard = {
          cardholderName: cardRecord.cardholder_name as string,
          brand: cardRecord.brand as string,
          number: cardRecord.number as string,
          expMonth: cardRecord.exp_month as string,
          expYear: cardRecord.exp_year as string,
          code: cardRecord.code as string
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
        const identityItem: CipherIdentity = {
          address1: identityRecord.address1 as string || null,
          address2: identityRecord.address2 as string || null,
          address3: identityRecord.address3 as string || null,
          city: identityRecord.city as string || null,
          company: identityRecord.company as string || null,
          country: identityRecord.country as string || null,
          email: identityRecord.email as string || null,
          firstName: identityRecord.first_name as string || null,
          lastName: identityRecord.last_name as string || null,
          licenseNumber: identityRecord.license_number as string || null,
          middleName: identityRecord.middle_name as string || null,
          passportNumber: identityRecord.passport_number as string || null,
          phone: identityRecord.phone as string || null,
          postalCode: identityRecord.postal_code as string || null,
          ssn: identityRecord.ssn as string || null,
          state: identityRecord.state as string || null,
          title: identityRecord.title as string || null,
          username: identityRecord.username as string || null
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
          fields.push({
            name: fieldData.name as string,
            value: fieldData.value as string,
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