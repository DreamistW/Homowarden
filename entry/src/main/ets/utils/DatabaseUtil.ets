import { Logger } from "@nzy/logger";
import { relationalStore } from "@kit.ArkData";
import { Context } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";

// 关系型数据库操作类
export class DatabaseUtil {
  private static instance: DatabaseUtil;
  private static store: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<void> | null = null;

  public static getInstance(): DatabaseUtil {
    if (DatabaseUtil.instance == null) {
      Logger.debug(`DatabaseUtil is not initialized`);
    }
    return DatabaseUtil.instance;
  }

  public static async init(context: Context): Promise<void> {
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: "homowarden.sql",
      securityLevel: relationalStore.SecurityLevel.S4,
      encrypt: true
    }
    if (!DatabaseUtil.initPromise) {
      DatabaseUtil.instance = new DatabaseUtil();
      DatabaseUtil.initPromise = new Promise((resolve, reject) => {
        relationalStore.getRdbStore(context, STORE_CONFIG, (err, store) => {
          if (err) {
            reject(err);
            Logger.error(`Failed to get RdbStore, message: ${err.message}`);
            return;
          }
          DatabaseUtil.store = store;
          resolve();
        });
      });
    }
    return DatabaseUtil.initPromise;
  }

  async executeSql(sql: string): Promise<boolean> {
    await DatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      if (DatabaseUtil.store != null) {
        DatabaseUtil.store.executeSql(sql, (err) => {
          if (err) {
            Logger.error(`Failed to execute sql: ${sql}, error message: ${err.message}`);
            reject(err);
          } else {
            resolve(true);
          }
        })
      } else {
        Logger.error(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }

  async insertData(table: string, data: relationalStore.ValuesBucket): Promise<number> {
    await DatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      if (DatabaseUtil.store != null) {
        DatabaseUtil.store.insert(table, data, (err, rowId) => {
          if (err) {
            Logger.error(`Insert into ${table} failed, message is ${err.message}`);
            reject(err);
            return;
          }
          Logger.debug(`Insert into ${table} successful, rowId = ${rowId}`);
          DatabaseUtil.store?.commit();
          resolve(rowId);
        })
      } else {
        Logger.error(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    });
  }

  async updateData(table: string, id: string, data: relationalStore.ValuesBucket): Promise<void> {
    await DatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo("id", id);
      if (DatabaseUtil.store != null) {
        DatabaseUtil.store.update(data, predicates, (err, rows) => {
          if (err) {
            Logger.error(`Update ${table} failed, message is ${err.message}`);
            reject(err);
            return;
          }
          Logger.debug(`Updated ${table}, row count: ${rows}`);
          DatabaseUtil.store?.commit();
          resolve();
        })
      } else {
        Logger.error(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }

  async deleteData(table: string, id: string): Promise<void> {
    await DatabaseUtil.initPromise;
    return new Promise((resolve, reject)=>{
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo("id", id);
      if (DatabaseUtil.store != null) {
        DatabaseUtil.store.delete(predicates, (err, rows) => {
          if (err) {
            Logger.error(`Delete from ${table} failed, message is ${err.message}`);
            resolve();
          }
          Logger.debug(`Deleted from ${table}, row count: ${rows}`);
          DatabaseUtil.store?.commit();
          resolve();
        })
      } else {
        Logger.error(`Database is undefined`);
        reject(new Error(`Database is undefined`));
      }
    })

  }

  async deleteAllData(table: string): Promise<void> {
    await DatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(table);
      if (DatabaseUtil.store != null) {
        DatabaseUtil.store.delete(predicates, (err, rows) => {
          if (err) {
            Logger.error(`Delete from ${table} failed, message is ${err.message}`);
            resolve();
          }
          Logger.debug(`Deleted from ${table}, row count: ${rows}`);
          DatabaseUtil.store?.commit();
          resolve();
        })
      } else {
        Logger.error(`Database is undefined`);
        reject(new Error(`Database is undefined`));
      }
    })
  }

  async queryAllData(table: string): Promise<relationalStore.ValuesBucket[]> {
    await DatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let result: relationalStore.ValuesBucket[] = [];
      let predicates = new relationalStore.RdbPredicates(table);
      if (DatabaseUtil.store != null) {
        DatabaseUtil.store.query(predicates, async (err, resultSet) => {
          if (err) {
            Logger.error(`Query ${table} failed, message is ${err.message}`);
            reject(err);
          } else {
            Logger.debug(`Query from ${table}, row count: ${resultSet.rowCount}`);
            while (resultSet.goToNextRow()) {
              result.push(resultSet.getRow());
            }
          }
          resultSet.close();
          resolve(result);
        })
      } else {
        Logger.error(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }

  async querySingleRow(table: string, id: string): Promise<relationalStore.ValuesBucket> {
    await DatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let result: relationalStore.ValuesBucket = {};
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo("id", id);
      if (DatabaseUtil.store != null) {
        DatabaseUtil.store.query(predicates, async (err, resultSet) => {
          if (err) {
            Logger.error(`Query ${table} failed, message is ${err.message}`);
            reject(err);
          } else {
            Logger.debug(`Query from ${table}, row count: ${resultSet.rowCount}}`);
            if (resultSet.goToNextRow()) {
              result = resultSet.getRow();
            }
          }
          resultSet.close();
          resolve(result);
        })
      } else {
        Logger.error(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }

  querySingleData(table: string, whereColumn: string, whereValue: string,
    needColumn: string): relationalStore.ValueType {
    let result: relationalStore.ValueType = '';
    try {
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo(whereColumn, whereValue);
      if (DatabaseUtil.store != null) {
        const resultSet = DatabaseUtil.store.querySync(predicates, [needColumn]);
        if (resultSet.goToNextRow()) {
          result = resultSet.getValue(resultSet.getColumnIndex(needColumn));
        }
      } else {
        Logger.error(`Database is undefined`);
      }
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Query ${table} failed, message is ${error.message}`);
    }
    return result;
  }

  createTable() {
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
    this.executeSql(createCiphersTable);
    this.executeSql(createLoginTable);
    this.executeSql(createCardTable);
    this.executeSql(createIdentityTable);
    this.executeSql(createSecureNoteTable);
    this.executeSql(createFieldsTable);

    Logger.debug('Database tables created successfully');
  }
}
