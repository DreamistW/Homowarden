import { asset } from '@kit.AssetStoreKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { Logger } from '@nzy/logger';
import {
  ACCESS_TOKEN_KEY, ACCESS_TOKEN_KEY_1, ACCESS_TOKEN_KEY_2, EMAIL_KEY, KDF_PARAM_KEY,
  MASTER_KEY, PRIVATE_KEY, PRIVATE_KEY_1, PRIVATE_KEY_2, REFRESH_TOKEN_KEY,
  TOKEN_EXPIRE_TIME_KEY, TWO_FACTOR_TOKEN_KEY, USER_KEY
} from './Constants';
import { CredentialDatabase } from './CredentialDatabase';

export const LEGACY_CREDENTIAL_ALIASES: string[] = [
  ACCESS_TOKEN_KEY_1, ACCESS_TOKEN_KEY_2, REFRESH_TOKEN_KEY, TOKEN_EXPIRE_TIME_KEY,
  TWO_FACTOR_TOKEN_KEY, MASTER_KEY, PRIVATE_KEY_1, PRIVATE_KEY_2, USER_KEY, KDF_PARAM_KEY, EMAIL_KEY
];

export interface LegacyCredentialSource {
  read(alias: string): string;
  remove(alias: string): void;
}

/** 仅升级迁移访问关键资产；读取失败不能冒充“没有资产”。 */
export class LegacyAssetSource implements LegacyCredentialSource {
  read(alias: string): string {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const rows = asset.querySync(query);
      if (rows.length === 0) {
        return '';
      }
      const secret = rows[0].get(asset.Tag.SECRET) as Uint8Array;
      return util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(secret);
    } catch (error) {
      if ((error as BusinessError).code === 24000002) {
        return '';
      }
      throw new Error(`Legacy credential read failed: code=${(error as BusinessError).code ?? 0}`);
    }
  }

  remove(alias: string): void {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(alias));
    try {
      asset.removeSync(query);
    } catch (error) {
      if ((error as BusinessError).code !== 24000002) {
        throw new Error('Legacy credential cleanup failed');
      }
    }
  }
}

export class LegacyCredentialMigration {
  static async run(database: CredentialDatabase, source: LegacyCredentialSource, loggedIn: boolean,
    owner: string): Promise<void> {
    let existing = database.readSync();
    if (!existing) {
      const legacy: Record<string, string> = {};
      // 在完整读取、事务提交及读回校验之前不删除任何旧资产。
      for (const alias of LEGACY_CREDENTIAL_ALIASES) {
        legacy[alias] = source.read(alias);
      }
      const values: Record<string, string> = {};
      values[EMAIL_KEY] = legacy[EMAIL_KEY];
      if (loggedIn) {
        values[ACCESS_TOKEN_KEY] = legacy[ACCESS_TOKEN_KEY_1] + legacy[ACCESS_TOKEN_KEY_2];
        values[PRIVATE_KEY] = legacy[PRIVATE_KEY_1] + legacy[PRIVATE_KEY_2];
        for (const alias of [REFRESH_TOKEN_KEY, TOKEN_EXPIRE_TIME_KEY, TWO_FACTOR_TOKEN_KEY,
          MASTER_KEY, USER_KEY, KDF_PARAM_KEY]) {
          values[alias] = legacy[alias];
        }
      }
      const usable = loggedIn && !!values[ACCESS_TOKEN_KEY] && !!values[REFRESH_TOKEN_KEY] &&
        !!values[MASTER_KEY] && !!values[USER_KEY] && !!values[KDF_PARAM_KEY] && !!values[EMAIL_KEY];
      existing = await database.replace(values, usable, usable ? owner : '', false);
      Logger.info(`Credential migration committed: loggedIn=${usable}`);
    }
    if (existing.legacyCleaned) {
      return;
    }
    try {
      for (const alias of LEGACY_CREDENTIAL_ALIASES) {
        source.remove(alias);
      }
      await database.markLegacyCleaned();
      Logger.info('Legacy credential assets cleaned');
    } catch (_) {
      // 数据库已是唯一数据源；重启时仅重试清理，绝不重新导入。
      Logger.warn('Legacy credential cleanup pending; database credentials remain active');
    }
  }
}
