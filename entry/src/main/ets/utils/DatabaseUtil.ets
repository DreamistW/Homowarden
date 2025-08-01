import { DbUtil } from "@abner/datastore";
import { BusinessError } from "@kit.BasicServicesKit";
import { Logger } from "@nzy/logger";
import { ValuesBucket } from "@kit.ArkData";

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
export function executeSql(sql: string): boolean {
  let result: boolean = false;
  DbUtil.getInstance().executeSql(sql, (isSuccess: boolean, err?: BusinessError) => {
    if (isSuccess) {
      Logger.debug(`Succeeded to execute sql: ${sql}`);
      result = true;
    } else {
      Logger.error(`Failed to execute sql ${sql}, error message: ${err?.message}`);
    }
  });
  return result;
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