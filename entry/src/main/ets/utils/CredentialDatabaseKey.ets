import { asset } from '@kit.AssetStoreKit';
import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { CryptoUtil } from './CryptoUtil';
import { Logger } from '@nzy/logger';
import { CredentialStorageError, CredentialStorageFailure } from './CredentialStorageError';

/** 启动时创建并复用凭据库随机密钥；不保存登录令牌，不轮换密钥。 */
export class CredentialDatabaseKey {
  static alias(name: string): string {
    if (!/^[a-zA-Z0-9_.-]+$/.test(name) || name.length > 220) {
      throw new Error('Invalid credential database key identifier');
    }
    return `credential_database_key:${name}`;
  }

  static databaseExists(context: Context, name: string): boolean {
    CredentialDatabaseKey.alias(name);
    const path = `${context.databaseDir}/rdb/${name}`;
    try {
      return ['', '-wal', '-shm', '-journal'].some((suffix: string) => fileIo.accessSync(path + suffix));
    } catch (error) {
      throw CredentialStorageError.wrap(error as Error, CredentialStorageFailure.DATABASE_CHECK);
    }
  }

  static async getOrCreate(context: Context, name: string): Promise<Uint8Array> {
    const existing = CredentialDatabaseKey.read(name);
    if (existing) {
      return existing;
    }
    if (CredentialDatabaseKey.databaseExists(context, name)) {
      throw new CredentialStorageError(CredentialStorageFailure.KEY_MISSING);
    }
    let key: Uint8Array;
    try {
      key = await CryptoUtil.generateRandom(32);
    } catch (error) {
      throw CredentialStorageError.wrap(error as Error, CredentialStorageFailure.KEY_CREATE);
    }
    try {
      if (key.length !== 32) {
        throw new CredentialStorageError(CredentialStorageFailure.KEY_CREATE);
      }
      const attributes: asset.AssetMap = new Map();
      attributes.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(CredentialDatabaseKey.alias(name)));
      attributes.set(asset.Tag.SECRET, key);
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
      attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
      attributes.set(asset.Tag.WRAP_TYPE, asset.WrapType.NEVER);
      // IS_PERSISTENT 默认 false。显式设置（包括 false）需要保留资产权限。
      // 不申请 STORE_PERSISTENT_DATA，并在保存后读回确认资产随卸载删除。
      let created = false;
      try {
        asset.addSync(attributes);
        created = true;
      } catch (error) {
        // 并发创建时复用胜出密钥；禁止覆盖已有密钥。
        if ((error as BusinessError).code !== 24000003) {
          throw CredentialStorageError.wrap(error as Error, CredentialStorageFailure.KEY_CREATE);
        }
      }
      const saved = CredentialDatabaseKey.read(name);
      if (!saved || (created && saved.some((value: number, index: number) => value !== key[index]))) {
        saved?.fill(0);
        throw new CredentialStorageError(CredentialStorageFailure.KEY_VERIFY);
      }
      if (created) {
        Logger.info('Credential database key created in Asset Store');
      }
      return saved;
    } finally {
      key.fill(0);
    }
  }

  static read(name: string): Uint8Array | null {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(CredentialDatabaseKey.alias(name)));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    let rows: asset.AssetMap[];
    try {
      rows = asset.querySync(query);
    } catch (error) {
      if ((error as BusinessError).code === 24000002) {
        return null;
      }
      throw CredentialStorageError.wrap(error as Error, CredentialStorageFailure.KEY_READ);
    }
    if (rows.length === 0) {
      return null;
    }
    const row = rows[0];
    const secret = row.get(asset.Tag.SECRET) as Uint8Array;
    try {
      if (!(secret instanceof Uint8Array) || secret.length !== 32 ||
        row.get(asset.Tag.SYNC_TYPE) !== asset.SyncType.NEVER ||
        row.get(asset.Tag.WRAP_TYPE) !== asset.WrapType.NEVER ||
        row.get(asset.Tag.IS_PERSISTENT) !== false ||
        row.get(asset.Tag.ACCESSIBILITY) !== asset.Accessibility.DEVICE_UNLOCKED) {
        throw new CredentialStorageError(CredentialStorageFailure.KEY_INVALID);
      }
      return new Uint8Array(secret);
    } finally {
      if (secret instanceof Uint8Array) {
        secret.fill(0);
      }
    }
  }

  static remove(name: string): void {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(CredentialDatabaseKey.alias(name)));
    try {
      asset.removeSync(query);
    } catch (error) {
      if ((error as BusinessError).code !== 24000002) {
        throw CredentialStorageError.wrap(error as Error, CredentialStorageFailure.KEY_REMOVE);
      }
    }
  }
}
