import { DbUtil } from "@abner/datastore";
import { BusinessError } from "@kit.BasicServicesKit";
import { Logger } from "@nzy/logger";
import { ValuesBucket } from "@kit.ArkData";
import { Cipher, CipherField } from "../model/CipherModels";
import { DBTableName } from "./Constants";

// 关系型数据库操作类

/**
 * 创建数据库表
 */
export function createTables(): void {
  // 创建密码项主表
  const createCiphersTable = `
    CREATE TABLE IF NOT EXISTS ciphers (
      id TEXT PRIMARY KEY,
      type INTEGER NOT NULL,
      name TEXT NOT NULL,
      favorite INTEGER DEFAULT 0,
      edit INTEGER DEFAULT 1,
      folder_id TEXT,
      organization_id TEXT,
      creation_date TEXT,
      revision_date TEXT,
      deleted_date TEXT,
      notes TEXT,
      reprompt INTEGER DEFAULT 0
    )
  `;

  // 创建登录信息表
  const createLoginTable = `
    CREATE TABLE IF NOT EXISTS cipher_logins (
      id TEXT PRIMARY KEY,
      cipher_id TEXT NOT NULL,
      username TEXT,
      password TEXT,
      password_revision_date TEXT,
      totp TEXT,
      uris TEXT,
      FOREIGN KEY (cipher_id) REFERENCES ciphers(id) ON DELETE CASCADE
    )
  `;

  // 创建卡片信息表
  const createCardTable = `
    CREATE TABLE IF NOT EXISTS cipher_cards (
      id TEXT PRIMARY KEY,
      cipher_id TEXT NOT NULL,
      cardholder_name TEXT,
      brand TEXT,
      number TEXT,
      exp_month TEXT,
      exp_year TEXT,
      code TEXT,
      FOREIGN KEY (cipher_id) REFERENCES ciphers(id) ON DELETE CASCADE
    )
  `;

  // 创建身份信息表
  const createIdentityTable = `
    CREATE TABLE IF NOT EXISTS cipher_identities (
      id TEXT PRIMARY KEY,
      cipher_id TEXT NOT NULL,
      title TEXT,
      first_name TEXT,
      middle_name TEXT,
      last_name TEXT,
      address1 TEXT,
      address2 TEXT,
      address3 TEXT,
      city TEXT,
      state TEXT,
      postal_code TEXT,
      country TEXT,
      company TEXT,
      email TEXT,
      phone TEXT,
      ssn TEXT,
      username TEXT,
      passport_number TEXT,
      license_number TEXT,
      FOREIGN KEY (cipher_id) REFERENCES ciphers(id) ON DELETE CASCADE
    )
  `;

  // 创建安全笔记表
  const createSecureNoteTable = `
    CREATE TABLE IF NOT EXISTS cipher_secure_notes (
      id TEXT PRIMARY KEY,
      cipher_id TEXT NOT NULL,
      type INTEGER DEFAULT 0,
      FOREIGN KEY (cipher_id) REFERENCES ciphers(id) ON DELETE CASCADE
    )
  `;

  // 创建自定义字段表
  const createFieldsTable = `
    CREATE TABLE IF NOT EXISTS cipher_fields (
      id TEXT PRIMARY KEY,
      cipher_id TEXT NOT NULL,
      name TEXT NOT NULL,
      value TEXT,
      type INTEGER DEFAULT 0,
      FOREIGN KEY (cipher_id) REFERENCES ciphers(id) ON DELETE CASCADE
    )
  `;

  // 执行创建表语句
  executeSql(createCiphersTable);
  executeSql(createLoginTable);
  executeSql(createCardTable);
  executeSql(createIdentityTable);
  executeSql(createSecureNoteTable);
  executeSql(createFieldsTable);

  Logger.debug('Database tables created successfully');
}

/**
 * 执行SQL语句
 * @param sql
 */
export async function executeSql(sql: string): Promise<boolean> {
  try {
    DbUtil.getInstance().executeSql(sql);
    return true;
  } catch (err) {
    const error = err as BusinessError;
    Logger.error(`Failed to execute sql: ${sql}, error message: ${error.message}`);
    return false;
  }
}

/**
 * 插入数据
 * @param table 表名
 * @param data 数据
 */
export function insertData(table: string, data: ValuesBucket) {
  try {
    DbUtil.getInstance().insertBean(table, data);
  } catch (err) {
    const error = err as BusinessError;
    Logger.error(`Failed to add data, error message: ${error.message}`);
  }
}

/**
 * 更新数据
 * @param table 表名
 * @param uuid 数据ID
 * @param data 新数据
 */
export function updateData(table: string, uuid: string, data: ValuesBucket) {
  try {
    DbUtil.getInstance().filterRdbPredicates({ equalTo: { "uuid": uuid } }).updateBean(table, data);
  } catch (err) {
    const error = err as BusinessError;
    Logger.error(`Failed to update data, error message: ${error.message}`);
  }
}


/**
 * 删除数据
 * @param table 表名
 * @param uuid 数据ID
 */
export function deleteData(table: string, uuid: string) {
  try {
    DbUtil.getInstance().filterRdbPredicates({ equalTo: { "uuid": uuid } }).deleteBean(table);
  } catch (err) {
    const error = err as BusinessError;
    Logger.error(`Failed to delete data, error message: ${error.message}`);
  }
}

/**
 * 删除表中所有数据
 * @param table 表名
 */
export async function deleteAllData(table: string) {
  const deleteSql = `DELETE FROM ${table}`;
  const result = await executeSql(deleteSql);
  if (result) {
    Logger.debug(`Successfully deleted all data from table: ${table}`);
  } else {
    Logger.error(`Failed to delete all data from table: ${table}`);
  }
}


/**
 * 查询表的所有数据
 * @param table 表名
 * @returns 数据
 */
export async function queryAllData(table: string): Promise<ValuesBucket[]> {
  let result: ValuesBucket[] = [];
  try {
    DbUtil.getInstance().queryAllBean(table, (data: ValuesBucket[]) => {
      result = data;
    })
  } catch (err) {
    const error = err as BusinessError;
    Logger.error(`Failed to query data, error message: ${error.message}`);
    return Promise.reject(err);
  }
  return result;
}


/**
 * 查询单条数据
 * @param table 表名
 * @param uuid 数据ID
 * @returns 数据
 */
export async function querySingleData(table: string, uuid: string): Promise<ValuesBucket> {
  let result: ValuesBucket = {};
  try {
    DbUtil.getInstance().filterRdbPredicates({ equalTo: { "uuid": uuid } }).queryBean(table, (data: ValuesBucket) => {
      result = data;
    })
  } catch (err) {
    const error = err as BusinessError;
    Logger.error(`Failed to query data, error message: ${error.message}`);
    return Promise.reject(err);
  }
  return result;
}

/**
 * 保存密码项到数据库
 * @param cipher 密码项对象
 */
export function saveCipherToDatabase(cipher: Cipher) {
  try {
    // 保存主表数据
    const cipherData: ValuesBucket = {
      id: cipher.id,
      type: cipher.type,
      name: cipher.name,
      favorite: cipher.favorite ? 1 : 0,
      edit: cipher.edit ? 1 : 0,
      folder_id: cipher.folderId || null,
      organization_id: cipher.organizationId || null,
      creation_date: cipher.creationDate,
      revision_date: cipher.revisionDate || null,
      deleted_date: cipher.deletedDate || null,
      notes: cipher.notes || null,
      reprompt: cipher.reprompt || 0
    };
    insertData(DBTableName.MAIN, cipherData);

    // 保存登录信息
    if (cipher.login && cipher.type === 1) {
      const loginData: ValuesBucket = {
        id: `${cipher.id}_login`,
        cipher_id: cipher.id,
        username: cipher.login.username || '',
        password: cipher.login.password || '',
        password_revision_date: cipher.login.passwordRevisionDate || null,
        totp: cipher.login.totp || null,
        uris: cipher.login.uris ? JSON.stringify(cipher.login.uris) : null
      };
      insertData(DBTableName.LOGINS, loginData);
    }

    // 保存卡片信息
    if (cipher.card && cipher.type === 3) {
      const cardData: ValuesBucket = {
        id: `${cipher.id}_card`,
        cipher_id: cipher.id,
        cardholder_name: cipher.card.cardholderName || '',
        brand: cipher.card.brand || '',
        number: cipher.card.number || '',
        exp_month: cipher.card.expMonth || '',
        exp_year: cipher.card.expYear || '',
        code: cipher.card.code || ''
      };
      insertData(DBTableName.CARDS, cardData);
    }

    // 保存身份信息
    if (cipher.identity && cipher.type === 4) {
      const identityData: ValuesBucket = {
        id: `${cipher.id}_identity`,
        cipher_id: cipher.id,
        title: cipher.identity.title || null,
        first_name: cipher.identity.firstName || null,
        middle_name: cipher.identity.middleName || null,
        last_name: cipher.identity.lastName || null,
        address1: cipher.identity.address1 || null,
        address2: cipher.identity.address2 || null,
        address3: cipher.identity.address3 || null,
        city: cipher.identity.city || null,
        state: cipher.identity.state || null,
        postal_code: cipher.identity.postalCode || null,
        country: cipher.identity.country || null,
        company: cipher.identity.company || null,
        email: cipher.identity.email || null,
        phone: cipher.identity.phone || null,
        ssn: cipher.identity.ssn || null,
        username: cipher.identity.username || null,
        passport_number: cipher.identity.passportNumber || null,
        license_number: cipher.identity.licenseNumber || null
      };
      insertData(DBTableName.IDENTITIES, identityData);
    }

    // 保存安全笔记
    if (cipher.secureNote && cipher.type === 2) {
      const noteData: ValuesBucket = {
        id: `${cipher.id}_note`,
        cipher_id: cipher.id,
        type: cipher.secureNote.type || 0
      };
      insertData(DBTableName.NOTES, noteData);
    }

    // 保存自定义字段
    if (cipher.fields && Array.isArray(cipher.fields)) {
      for (let i = 0; i < cipher.fields.length; i++) {
        const field = cipher.fields[i] as CipherField;
        const fieldData: ValuesBucket = {
          id: `${cipher.id}_field_${i}`,
          cipher_id: cipher.id,
          name: field.name || '',
          value: field.value || '',
          type: field.type || 0
        };
        insertData(DBTableName.FIELDS, fieldData);
      }
    }

    Logger.debug(`Successfully saved cipher ${cipher.id} to database`);
  } catch (err) {
    const error = err as BusinessError;
    Logger.error(`Failed to save cipher to database, error message: ${error.message}`);
  }
}