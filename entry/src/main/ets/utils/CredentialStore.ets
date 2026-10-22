import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DataPreferences } from '@abner/datastore';
import { Logger } from '@nzy/logger';
import { CredentialDatabase, CredentialSnapshot } from './CredentialDatabase';
import { LegacyAssetSource, LegacyCredentialMigration } from './LegacyCredentialMigration';
import { RefreshTokenResponse } from '../model/RefreshToken';
import { QuickEntryManager } from './QuickEntryManager';
import { CredentialStorageError, CredentialStorageFailure } from './CredentialStorageError';
import {
  AUTO_LOCK_TIMEOUT, BIOMETRIC_AUTH, EMAIL_KEY, LOGIN_STATUS_KEY,
  SERVER_ADDRESS_KEY, SERVER_TYPE_KEY, ServerType,
  TWO_FACTOR_TOKEN_KEY
} from './Constants';

/** 凭据的唯一读写入口；不向日志输出数据库内容。 */
export class CredentialStore {
  private static database: CredentialDatabase | null = null;
  private static initialization: Promise<void> | null = null;
  private static repairOperation: Promise<void> | null = null;
  private static context: Context | null = null;

  static initialize(context: Context): Promise<void> {
    CredentialStore.context = context;
    if (!CredentialStore.initialization) {
      const pending: Promise<void> = CredentialStore.open(context).catch((error: Error) => {
        if (CredentialStore.initialization === pending) {
          CredentialStore.initialization = null;
        }
        throw error;
      });
      CredentialStore.initialization = pending;
    }
    return CredentialStore.initialization;
  }

  static async ready(): Promise<void> {
    if (!CredentialStore.context) {
      throw new Error('Credential storage is not initialized');
    }
    await CredentialStore.initialize(CredentialStore.context);
  }

  private static async open(context: Context): Promise<void> {
    let phase = 'preferences';
    let fallback = CredentialStorageFailure.PREFERENCES;
    let database: CredentialDatabase | null = null;
    try {
      const oldPreferences = await preferences.getPreferences(context, { name: 'harmonyPreferences' });
      phase = 'database';
      fallback = CredentialStorageFailure.DATABASE_INITIALIZE;
      database = await CredentialDatabase.open(context);
      phase = 'legacy-status';
      const existing = database.readSync();
      let owner = existing?.owner ?? '';
      let loggedIn = existing?.loggedIn ?? false;
      if (!existing) {
        loggedIn = oldPreferences.getSync(LOGIN_STATUS_KEY, 0) === 1;
        const source = new LegacyAssetSource();
        owner = CredentialStore.ownerKey(
          oldPreferences.getSync(SERVER_TYPE_KEY, ServerType.US) as ServerType,
          oldPreferences.getSync(SERVER_ADDRESS_KEY, '') as string, source.read(EMAIL_KEY));
      }
      phase = 'legacy-migration';
      fallback = CredentialStorageFailure.LEGACY_MIGRATION;
      await LegacyCredentialMigration.run(database, new LegacyAssetSource(), loggedIn, owner);
      // 数据库中的状态为准，首选项只作为旧版状态的兼容镜像。
      try {
        oldPreferences.putSync(LOGIN_STATUS_KEY, database.readSync()?.loggedIn ? 1 : 0);
        await oldPreferences.flush();
      } catch (_) {
        Logger.warn('Login status preference mirror failed; database remains authoritative');
      }
      CredentialStore.database = database;
      await QuickEntryManager.updateLoginState(database.readSync()?.loggedIn ?? false);
      Logger.info('Encrypted credential database ready');
    } catch (error) {
      const failure = CredentialStorageError.wrap(error as Error, fallback);
      Logger.error(`Credential storage initialization failed: phase=${phase}, ` +
        `code=${failure.code}, reason=${failure.reason}`);
      database?.close();
      throw failure;
    }
  }

  /** 调用方必须先取得清空本机凭据库的二次确认。 */
  static repair(context: Context): Promise<void> {
    if (CredentialStore.repairOperation) {
      return CredentialStore.repairOperation;
    }
    const previous = CredentialStore.initialization;
    CredentialStore.context = context;
    const repair = (async (): Promise<void> => {
      // 等待启动初始化结束，避免读库与删除交错。
      await previous?.catch(() => {});
      CredentialStore.database?.close();
      CredentialStore.database = null;
      // 即使清空过程被中断，也不能在下次启动恢复旧登录状态。
      try {
        const oldPreferences = await preferences.getPreferences(context, { name: 'harmonyPreferences' });
        oldPreferences.putSync(LOGIN_STATUS_KEY, 0);
        await oldPreferences.flush();
      } catch (error) {
        throw CredentialStorageError.wrap(error as Error, CredentialStorageFailure.PREFERENCES);
      }
      const database = await CredentialDatabase.recreate(context);
      try {
        await LegacyCredentialMigration.run(database, new LegacyAssetSource(), false, '');
      } catch (error) {
        database.close();
        throw CredentialStorageError.wrap(error as Error, CredentialStorageFailure.LEGACY_MIGRATION);
      }
      CredentialStore.database = database;
      CredentialStore.mirrorStatus(false);
      await QuickEntryManager.updateLoginState(false);
      Logger.info('Local credential storage repaired; login required');
    })();
    CredentialStore.repairOperation = repair.catch((error: Error) => {
      CredentialStore.initialization = null;
      throw CredentialStorageError.wrap(error, CredentialStorageFailure.DATABASE_INITIALIZE);
    }).finally(() => {
      CredentialStore.repairOperation = null;
    });
    CredentialStore.initialization = CredentialStore.repairOperation;
    return CredentialStore.repairOperation;
  }

  static ownerKey(serverType: ServerType, address: string, email: string): string {
    const serverAddress = serverType === ServerType.SELF_HOSTED ? address.trim().replace(/\/+$/, '') : '';
    return JSON.stringify([serverType, serverAddress, email.trim().toLowerCase()]);
  }

  private static getDatabase(): CredentialDatabase {
    if (!CredentialStore.database) {
      throw new Error('Credential storage is not ready');
    }
    return CredentialStore.database;
  }

  static readSnapshotSync(): CredentialSnapshot {
    const snapshot = CredentialStore.getDatabase().readSync();
    if (!snapshot) {
      throw new Error('Credential record is missing');
    }
    return snapshot;
  }

  static querySync(alias: string): string {
    return CredentialStore.readSnapshotSync().values[alias] ?? '';
  }

  static isLoggedInSync(): boolean {
    return CredentialStore.readSnapshotSync().loggedIn;
  }

  static sessionSync(): CredentialSnapshot {
    const snapshot = CredentialStore.readSnapshotSync();
    const prefs = DataPreferences.getInstance();
    const owner = CredentialStore.ownerKey(prefs.getSync<ServerType>(SERVER_TYPE_KEY, ServerType.US),
      prefs.getSync<string>(SERVER_ADDRESS_KEY, ''), snapshot.values[EMAIL_KEY] ?? '');
    if (!snapshot.loggedIn || snapshot.owner !== owner) {
      throw new Error('Login required or server changed');
    }
    return snapshot;
  }

  static rememberedTwoFactorSync(owner: string): string {
    const snapshot = CredentialStore.readSnapshotSync();
    return snapshot.loggedIn && snapshot.owner === owner ? snapshot.values[TWO_FACTOR_TOKEN_KEY] ?? '' : '';
  }

  static async replaceLogin(values: Record<string, string>, owner: string): Promise<void> {
    const old = CredentialStore.readSnapshotSync();
    const database = CredentialStore.getDatabase();
    await database.replace(values, true, owner, old.legacyCleaned);
    // 提交后重试清理旧版残留资产。
    await LegacyCredentialMigration.run(database, new LegacyAssetSource(), true, owner);
    CredentialStore.mirrorStatus(true);
    await QuickEntryManager.updateLoginState(true);
    Logger.info('Login credentials committed to encrypted database');
  }

  static async applyRefresh(snapshot: CredentialSnapshot, response: RefreshTokenResponse): Promise<void> {
    const current = CredentialStore.sessionSync();
    if (current.revision !== snapshot.revision || current.owner !== snapshot.owner) {
      throw new Error('Credential session changed');
    }
    await CredentialStore.getDatabase().refresh(snapshot, response);
    Logger.info('Refreshed tokens committed to encrypted database');
  }

  static async clear(): Promise<void> {
    const old = CredentialStore.readSnapshotSync();
    const values: Record<string, string> = {};
    // 保留邮箱供“记住邮箱”显示；清空记录仍保留，阻止重新导入残留旧资产。
    values[EMAIL_KEY] = old.values[EMAIL_KEY] ?? '';
    await CredentialStore.getDatabase().replace(values, false, '', old.legacyCleaned);
    CredentialStore.mirrorStatus(false);
    await QuickEntryManager.updateLoginState(false);
    try {
      DataPreferences.getInstance().putSync(BIOMETRIC_AUTH, 0);
      DataPreferences.getInstance().putSync(AUTO_LOCK_TIMEOUT, 0);
    } catch (_) {
      Logger.warn('Logout preference reset failed; database credentials remain cleared');
    }
    Logger.info('Database credentials cleared');
  }

  static async deactivate(): Promise<void> {
    const old = CredentialStore.readSnapshotSync();
    await CredentialStore.getDatabase().replace(old.values, false, old.owner, old.legacyCleaned);
    CredentialStore.mirrorStatus(false);
    await QuickEntryManager.updateLoginState(false);
  }

  private static mirrorStatus(loggedIn: boolean): void {
    try {
      DataPreferences.getInstance().putSync(LOGIN_STATUS_KEY, loggedIn ? 1 : 0);
    } catch (_) {
      Logger.warn('Login status preference mirror failed; database remains authoritative');
    }
  }
}
