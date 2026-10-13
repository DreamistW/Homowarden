import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RefreshTokenResponse } from '../model/RefreshToken';
import { ACCESS_TOKEN_KEY, REFRESH_TOKEN_KEY, TOKEN_EXPIRE_TIME_KEY } from './Constants';
import { CredentialDatabaseKey } from './CredentialDatabaseKey';

export interface CredentialSnapshot {
  revision: number;
  loggedIn: boolean;
  owner: string;
  values: Record<string, string>;
  legacyCleaned: boolean;
}

const TABLE = 'credentials';
const SCHEMA_VERSION = 1;

/** 独立加密库；整组凭据及登录状态在同一个事务中替换。 */
export class CredentialDatabase {
  private store: relationalStore.RdbStore | null = null;
  private failed: boolean = false;
  private writes: Promise<void> = Promise.resolve();

  private constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  static async open(context: Context, name: string = 'homowarden_credentials.db'): Promise<CredentialDatabase> {
    const key = await CredentialDatabaseKey.getOrCreate(context, name);
    const config: relationalStore.StoreConfig = {
      name: name,
      securityLevel: relationalStore.SecurityLevel.S4,
      encrypt: true,
      allowRebuild: false,
      cryptoParam: {
        encryptionKey: key,
        encryptionAlgo: relationalStore.EncryptionAlgo.AES_256_GCM
      }
    };
    // 不注册分布式表，不调用备份/同步接口；应用 backup_config 禁止备份恢复。
    let store: relationalStore.RdbStore;
    try {
      store = await relationalStore.getRdbStore(context, config);
    } catch (_) {
      throw new Error('Credential database open failed');
    } finally {
      key.fill(0);
    }
    try {
      await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE} (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        schema_version INTEGER NOT NULL,
        revision INTEGER NOT NULL,
        logged_in INTEGER NOT NULL,
        owner TEXT NOT NULL,
        payload TEXT NOT NULL,
        legacy_cleaned INTEGER NOT NULL
      )`);
      const database = new CredentialDatabase(store);
      database.readSync();
      return database;
    } catch (_) {
      store.close();
      throw new Error('Credential database initialization failed');
    }
  }

  readSync(transaction?: relationalStore.Transaction): CredentialSnapshot | null {
    if (this.failed) {
      throw new Error('Credential database must be reopened');
    }
    if (!this.store) {
      throw new Error('Credential database is unavailable');
    }
    const sql = `SELECT * FROM ${TABLE} WHERE id = 1`;
    const result = transaction ? transaction.querySqlSync(sql) : this.store.querySqlSync(sql);
    try {
      if (!result.goToFirstRow()) {
        return null;
      }
      if (result.getLong(result.getColumnIndex('schema_version')) !== SCHEMA_VERSION) {
        throw new Error('Unsupported credential database schema');
      }
      let values: Record<string, string>;
      try {
        values = JSON.parse(result.getString(result.getColumnIndex('payload'))) as Record<string, string>;
        if (values === null || Array.isArray(values) || typeof values !== 'object' ||
          Object.keys(values).some((key: string) => typeof values[key] !== 'string')) {
          throw new Error('Invalid values');
        }
      } catch (_) {
        // JSON 解析错误可能带上原文，不能将凭据带入异常或日志。
        throw new Error('Invalid credential database payload');
      }
      return {
        revision: result.getLong(result.getColumnIndex('revision')),
        loggedIn: result.getLong(result.getColumnIndex('logged_in')) === 1,
        owner: result.getString(result.getColumnIndex('owner')),
        values: values,
        legacyCleaned: result.getLong(result.getColumnIndex('legacy_cleaned')) === 1
      };
    } finally {
      result.close();
    }
  }

  replace(values: Record<string, string>, loggedIn: boolean, owner: string,
    legacyCleaned: boolean, expectedRevision?: number): Promise<CredentialSnapshot> {
    return this.serialize(() => this.replaceInTransaction(values, loggedIn, owner, legacyCleaned, expectedRevision));
  }

  private async replaceInTransaction(values: Record<string, string>, loggedIn: boolean, owner: string,
    legacyCleaned: boolean, expectedRevision?: number): Promise<CredentialSnapshot> {
    if (this.failed) {
      throw new Error('Credential database must be reopened');
    }
    if (!this.store) {
      throw new Error('Credential database is unavailable');
    }
    const transaction = await this.store.createTransaction({ transactionType: relationalStore.TransactionType.IMMEDIATE });
    let operation = 'read';
    try {
      const previous = this.readSync(transaction);
      if (expectedRevision !== undefined && previous?.revision !== expectedRevision) {
        throw new Error('Credential session changed');
      }
      const revision = (previous?.revision ?? 0) + 1;
      const payload = JSON.stringify(values);
      const row: relationalStore.ValuesBucket = {
        id: 1,
        schema_version: SCHEMA_VERSION,
        revision: revision,
        logged_in: loggedIn ? 1 : 0,
        owner: owner,
        payload: payload,
        legacy_cleaned: legacyCleaned ? 1 : 0
      };
      operation = 'write';
      transaction.insertSync(TABLE, row, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      operation = 'verify';
      const saved = this.readSync(transaction);
      if (!saved || saved.revision !== revision || saved.owner !== owner || saved.loggedIn !== loggedIn ||
        Object.keys(saved.values).length !== Object.keys(values).length ||
        Object.keys(values).some((key: string) => saved.values[key] !== values[key]) ||
        saved.legacyCleaned !== legacyCleaned) {
        throw new Error('Credential database verification failed');
      }
      operation = 'commit';
      await transaction.commit();
      return saved;
    } catch (error) {
      await transaction.rollback();
      throw new Error(`Credential database transaction failed: operation=${operation}, ` +
        `code=${(error as BusinessError).code ?? 0}`);
    }
  }

  async markLegacyCleaned(): Promise<void> {
    // 清理标记不改变登录版本，避免无关清理使正在刷新令牌的会话失效。
    await this.serialize(async () => {
      if (!this.store || this.failed) {
        throw new Error('Credential database is not persisted');
      }
      await this.store.executeSql(`UPDATE ${TABLE} SET legacy_cleaned = 1 WHERE id = 1`);
    });
  }

  async refresh(snapshot: CredentialSnapshot, response: RefreshTokenResponse): Promise<void> {
    if (!response.access_token || !Number.isFinite(response.expires_in) || response.expires_in <= 0 ||
      (response.refresh_token !== undefined &&
        (typeof response.refresh_token !== 'string' || response.refresh_token.length === 0))) {
      throw new Error('Invalid refresh token response');
    }
    const current = this.readSync();
    if (!current || !current.loggedIn || current.revision !== snapshot.revision || current.owner !== snapshot.owner) {
      throw new Error('Credential session changed');
    }
    current.values[ACCESS_TOKEN_KEY] = response.access_token;
    current.values[REFRESH_TOKEN_KEY] = response.refresh_token ?? current.values[REFRESH_TOKEN_KEY];
    current.values[TOKEN_EXPIRE_TIME_KEY] = String(Math.floor(Date.now() / 1000) + response.expires_in);
    await this.replace(current.values, true, current.owner, current.legacyCleaned, snapshot.revision);
  }

  private serialize<T>(action: () => Promise<T>): Promise<T> {
    const result = this.writes.then(action);
    this.writes = result.then(() => {}, () => {});
    return result;
  }

  close(): void {
    this.store?.close();
    this.store = null;
    this.failed = true;
  }

}
