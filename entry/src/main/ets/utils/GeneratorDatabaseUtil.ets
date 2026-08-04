import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { Context } from '@kit.AbilityKit';

/** 生成器历史记录表名。 */
export const GENERATOR_HISTORY_TABLE = 'generator_history';

// 生成器历史记录关系型数据库操作类
export class GeneratorDatabaseUtil {
  private static instance: GeneratorDatabaseUtil;
  private static store: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<void> | null = null;

  public static getInstance(): GeneratorDatabaseUtil {
    if (GeneratorDatabaseUtil.instance == null) {
      console.log(`GeneratorDatabaseUtil is not initialized`);
    }
    return GeneratorDatabaseUtil.instance;
  }

  public static async init(context: Context): Promise<void> {
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: 'generator_history.sql',
      securityLevel: relationalStore.SecurityLevel.S4,
      encrypt: true
    }
    if (!GeneratorDatabaseUtil.initPromise) {
      GeneratorDatabaseUtil.instance = new GeneratorDatabaseUtil();
      const storePromise: Promise<void> = new Promise((resolve, reject) => {
        relationalStore.getRdbStore(context, STORE_CONFIG, (err, store) => {
          if (err) {
            reject(err);
            console.log(`Failed to get RdbStore, message: ${err.message}`);
            return;
          }
          GeneratorDatabaseUtil.store = store;
          resolve();
        });
      });
      GeneratorDatabaseUtil.initPromise = storePromise.then(async () => {
        await GeneratorDatabaseUtil.getInstance().createTables();
      });
    }
    return GeneratorDatabaseUtil.initPromise;
  }

  // 创建数据表
  async createTables(): Promise<void> {
    const createHistoryTableSql = `
      CREATE TABLE IF NOT EXISTS generator_history (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    `;
    try {
      await this.executeSqlDirectly(createHistoryTableSql);
      console.log('Generator history table created successfully');
    } catch (err) {
      const error = err as BusinessError;
      console.log(`Failed to create generator history table, message: ${error.message}`);
      throw new Error(`Failed to create generator history table: ${error.message}`);
    }
  }

  // 生成唯一ID
  generateId(): string {
    return `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  async executeSql(sql: string): Promise<boolean> {
    await GeneratorDatabaseUtil.initPromise;
    return this.executeSqlDirectly(sql);
  }

  private executeSqlDirectly(sql: string): Promise<boolean> {
    return new Promise((resolve, reject) => {
      if (GeneratorDatabaseUtil.store != null) {
        GeneratorDatabaseUtil.store.executeSql(sql, (err) => {
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
    await GeneratorDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      if (GeneratorDatabaseUtil.store != null) {
        GeneratorDatabaseUtil.store.insert(table, data, (err, rowId) => {
          if (err) {
            console.log(`Insert into ${table} failed, message is ${err.message}`);
            reject(err);
            return;
          }
          console.log(`Insert into ${table} successful, rowId = ${rowId}`);
          try {
            GeneratorDatabaseUtil.store?.commit();
            resolve(rowId);
          } catch (error) {
            reject(error);
          }
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    });
  }

  async deleteData(table: string, id: string): Promise<void> {
    await GeneratorDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(table);
      predicates.equalTo('id', id);
      if (GeneratorDatabaseUtil.store != null) {
        GeneratorDatabaseUtil.store.delete(predicates, (err, rows) => {
          if (err) {
            console.log(`Delete from ${table} failed, message is ${err.message}`);
            reject(err);
            return;
          }
          console.log(`Deleted from ${table}, row count: ${rows}`);
          try {
            GeneratorDatabaseUtil.store?.commit();
            resolve();
          } catch (error) {
            reject(error);
          }
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error(`Database is undefined`));
      }
    })

  }

  async deleteAllData(table: string): Promise<void> {
    await GeneratorDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let predicates = new relationalStore.RdbPredicates(table);
      if (GeneratorDatabaseUtil.store != null) {
        GeneratorDatabaseUtil.store.delete(predicates, (err, rows) => {
          if (err) {
            console.log(`Delete from ${table} failed, message is ${err.message}`);
            reject(err);
            return;
          }
          console.log(`Deleted from ${table}, row count: ${rows}`);
          try {
            GeneratorDatabaseUtil.store?.commit();
            resolve();
          } catch (error) {
            reject(error);
          }
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error(`Database is undefined`));
      }
    })
  }

  // 按时间倒序查询全部历史记录
  async queryAllHistory(): Promise<relationalStore.ValuesBucket[]> {
    await GeneratorDatabaseUtil.initPromise;
    return new Promise((resolve, reject) => {
      let result: relationalStore.ValuesBucket[] = [];
      let predicates = new relationalStore.RdbPredicates(GENERATOR_HISTORY_TABLE);
      predicates.orderByDesc('timestamp');
      if (GeneratorDatabaseUtil.store != null) {
        GeneratorDatabaseUtil.store.query(predicates, async (err, resultSet) => {
          if (err) {
            console.log(`Query generator history failed, message: ${err.message}`);
            reject(err);
            return;
          }
          try {
            console.log(`Query from generator history, row count: ${resultSet.rowCount}`);
            while (resultSet.goToNextRow()) {
              result.push(resultSet.getRow());
            }
            resultSet.close();
            resolve(result);
          } catch (error) {
            try {
              resultSet.close();
            } catch (closeError) {
              console.log(`Failed to close generator history result set: ${closeError}`);
            }
            reject(error);
          }
        })
      } else {
        console.log(`Database is undefined`);
        reject(new Error('Database is undefined'));
      }
    })
  }
}
