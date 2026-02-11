import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { Context } from '@kit.AbilityKit';

// 关系型数据库操作类
export class ShareDatabaseUtil {
  private static instance: ShareDatabaseUtil;
  private static store: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<void> | null = null;

  public static getInstance(): ShareDatabaseUtil {
    if (ShareDatabaseUtil.instance == null) {
      console.log(`DatabaseUtil is not initialized`);
    }
    return ShareDatabaseUtil.instance;
  }

  public static async init(context: Context): Promise<void> {
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: "sure2share.sql",
      securityLevel: relationalStore.SecurityLevel.S4,
      encrypt: true
    }
    if (!ShareDatabaseUtil.initPromise) {
      ShareDatabaseUtil.instance = new ShareDatabaseUtil();
      ShareDatabaseUtil.initPromise = new Promise((resolve, reject) => {
        relationalStore.getRdbStore(context, STORE_CONFIG, (err, store) => {
          if (err) {
            reject(err);
            console.log(`Failed to get RdbStore, message: ${err.message}`);
            return;
          }
          ShareDatabaseUtil.store = store;
          resolve();
        });
      });
    }
    ShareDatabaseUtil.getInstance().createTables();
    return ShareDatabaseUtil.initPromise;
  }

  // 创建数据表
  async createTables(): Promise<void> {
    const createHistoryTableSql = `
      CREATE TABLE IF NOT EXISTS history (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    `;
    try {
      await this.executeSql(createHistoryTableSql);
      console.log('History table created successfully');
    } catch (err) {
      const error = err as BusinessError;
      console.log(`Failed to create history table, message: ${error.message}`);
    }
  }

  // 生成唯一ID
  generateId(): string {
    return `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  async executeSql(sql: string): Promise<boolean> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.executeSql(sql, (err) => {
          if (err) {
            console.log(`Failed to execute sql: ${sql}, error message: ${err.message}`);
            reject(err);
          } else {
            resolve(true);
          }
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }

  async insertData(table: string, data: relationalStore.ValuesBucket): Promise<number> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.insert(table, data, (err, rowId) => {
          if (err) {
            console.log(`Insert into ${table} failed, message is ${err.message}`);
            reject(err);
            return;
          }
          console.log(`Insert into ${table} successful, rowId = ${rowId}`);
          ShareDatabaseUtil.store?.commit();
          resolve(rowId);
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    });
  }

  async updateData(table: string, id: string, data: relationalStore.ValuesBucket): Promise<void> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo("id", id);
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.update(data, predicates, (err, rows) => {
          if (err) {
            console.log(`Update ${table} failed, message is ${err.message}`);
            reject(err);
            return;
          }
          console.log(`Updated ${table}, row count: ${rows}`);
          ShareDatabaseUtil.store?.commit();
          resolve();
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }

  async deleteData(table: string, id: string): Promise<void> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo("id", id);
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.delete(predicates, (err, rows) => {
          if (err) {
            console.log(`Delete from ${table} failed, message is ${err.message}`);
            resolve();
          }
          console.log(`Deleted from ${table}, row count: ${rows}`);
          ShareDatabaseUtil.store?.commit();
          resolve();
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error(`Database is undefined`));
      }
    })

  }

  async deleteAllData(table: string): Promise<void> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(table);
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.delete(predicates, (err, rows) => {
          if (err) {
            console.log(`Delete from ${table} failed, message is ${err.message}`);
            resolve();
          }
          console.log(`Deleted from ${table}, row count: ${rows}`);
          ShareDatabaseUtil.store?.commit();
          resolve();
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error(`Database is undefined`));
      }
    })
  }

  async queryAllData(table: string): Promise<relationalStore.ValuesBucket[]> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let result: relationalStore.ValuesBucket[] = [];
      let predicates = new relationalStore.RdbPredicates(table);
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.query(predicates, async (err, resultSet) => {
          if (err) {
            console.log(`Query ${table} failed, message is ${err.message}`);
            reject(err);
          } else {
            console.log(`Query from ${table}, row count: ${resultSet.rowCount}`);
            while (resultSet.goToNextRow()) {
              result.push(resultSet.getRow());
            }
          }
          resultSet.close();
          resolve(result);
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }

  async querySingleRow(table: string, id: string): Promise<relationalStore.ValuesBucket> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let result: relationalStore.ValuesBucket = {};
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo("id", id);
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.query(predicates, async (err, resultSet) => {
          if (err) {
            console.log(`Query ${table} failed, message is ${err.message}`);
            reject(err);
          } else {
            console.log(`Query from ${table}, row count: ${resultSet.rowCount}}`);
            if (resultSet.goToNextRow()) {
              result = resultSet.getRow();
            }
          }
          resultSet.close();
          resolve(result);
        })
      } else {
        console.log(`Database is undefined`);
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
      if (ShareDatabaseUtil.store != null) {
        const resultSet = ShareDatabaseUtil.store.querySync(predicates, [needColumn]);
        if (resultSet.goToNextRow()) {
          result = resultSet.getValue(resultSet.getColumnIndex(needColumn));
        }
      } else {
        console.log(`Database is undefined`);
      }
    } catch (err) {
      const error = err as BusinessError;
      console.log(`Query ${table} failed, message is ${error.message}`);
    }
    return result;
  }

  // 根据搜索条件查询历史记录
  async queryHistoryBySearch(searchText: string): Promise<relationalStore.ValuesBucket[]> {
    await ShareDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let result: relationalStore.ValuesBucket[] = [];
      let predicates = new relationalStore.RdbPredicates('history');
      if (searchText && searchText.trim() !== '') {
        predicates.contains('content', searchText);
      }
      predicates.orderByDesc('timestamp'); // 按时间倒序排列
      if (ShareDatabaseUtil.store != null) {
        ShareDatabaseUtil.store.query(predicates, async (err, resultSet) => {
          if (err) {
            console.log(`Query history failed, message: ${err.message}`);
            reject(err);
          } else {
            console.log(`Query from history, row count: ${resultSet.rowCount}`);
            while (resultSet.goToNextRow()) {
              result.push(resultSet.getRow());
            }
          }
          resultSet.close();
          resolve(result);
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }
}