import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore } from '@kit.ArkData';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { CredentialDatabaseKey } from '../../../main/ets/utils/CredentialDatabaseKey';
import { CryptoUtil } from '../../../main/ets/utils/CryptoUtil';
import { CredentialDatabase, CredentialSnapshot } from '../../../main/ets/utils/CredentialDatabase';
import { LegacyCredentialMigration, LegacyCredentialSource,
  LEGACY_CREDENTIAL_ALIASES } from '../../../main/ets/utils/LegacyCredentialMigration';
import {
  ACCESS_TOKEN_KEY, ACCESS_TOKEN_KEY_1, ACCESS_TOKEN_KEY_2, EMAIL_KEY, KDF_PARAM_KEY, MASTER_KEY,
  PRIVATE_KEY, PRIVATE_KEY_1, PRIVATE_KEY_2, REFRESH_TOKEN_KEY, TOKEN_EXPIRE_TIME_KEY,
  TWO_FACTOR_TOKEN_KEY, USER_KEY
} from '../../../main/ets/utils/Constants';

class FixtureLegacySource implements LegacyCredentialSource {
  values: Record<string, string> = {};
  reads: number = 0;
  removals: number = 0;
  failRead: boolean = false;
  failRemove: boolean = false;

  read(alias: string): string {
    this.reads++;
    if (this.failRead) {
      throw new Error('Injected legacy read failure');
    }
    return this.values[alias] ?? '';
  }

  remove(alias: string): void {
    if (this.failRemove) {
      throw new Error('Injected legacy cleanup failure');
    }
    this.removals++;
    this.values[alias] = '';
  }
}

function fixtureSource(): FixtureLegacySource {
  const source = new FixtureLegacySource();
  source.values[ACCESS_TOKEN_KEY_1] = 'a'.repeat(1000);
  source.values[ACCESS_TOKEN_KEY_2] = 'b'.repeat(900);
  source.values[PRIVATE_KEY_1] = 'c'.repeat(1000);
  source.values[PRIVATE_KEY_2] = 'd'.repeat(900);
  source.values[REFRESH_TOKEN_KEY] = 'fixture-refresh';
  source.values[TWO_FACTOR_TOKEN_KEY] = 'fixture-remember';
  source.values[TOKEN_EXPIRE_TIME_KEY] = '100';
  source.values[MASTER_KEY] = 'fixture-master';
  source.values[USER_KEY] = 'fixture-wrapped-user';
  source.values[KDF_PARAM_KEY] = '{"kdf":1,"salt":"fixture@example.com","kdfIterations":6}';
  source.values[EMAIL_KEY] = 'fixture@example.com';
  return source;
}

async function rejects(action: () => Promise<CredentialSnapshot | void>): Promise<void> {
  let rejected = false;
  try {
    await action();
  } catch (_) {
    rejected = true;
  }
  expect(rejected).assertTrue();
}

function keyQuery(name: string): asset.AssetMap {
  const query: asset.AssetMap = new Map();
  query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(CredentialDatabaseKey.alias(name)));
  return query;
}

export default function credentialStorageTest(): void {
  describe('CredentialStorage', () => {
    it('encryptedDatabaseMigrationAndRefresh', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.dreamist.homowarden', abilityName: 'EntryAbility' });
      const ability = await delegator.getCurrentTopAbility();
      const context = ability.context;
      const name = `credential_fixture_${Date.now()}.db`;
      let database = await CredentialDatabase.open(context, name);
      try {
        // 读失败：未写入迁移标记，未删除旧值，下次可以重试。
        const source = fixtureSource();
        source.failRead = true;
        await rejects(() => LegacyCredentialMigration.run(database, source, true, 'fixture-owner'));
        expect(database.readSync() === null).assertTrue();
        expect(source.removals).assertEqual(0);
        source.failRead = false;
        source.failRemove = true;
        await LegacyCredentialMigration.run(database, source, true, 'fixture-owner');
        let snapshot = database.readSync()!;
        expect(snapshot.loggedIn).assertTrue();
        expect(snapshot.legacyCleaned).assertFalse();
        expect(snapshot.values[ACCESS_TOKEN_KEY]).assertEqual('a'.repeat(1000) + 'b'.repeat(900));
        expect(snapshot.values[PRIVATE_KEY]).assertEqual('c'.repeat(1000) + 'd'.repeat(900));
        expect(snapshot.values[MASTER_KEY]).assertEqual('fixture-master');
        expect(snapshot.values[USER_KEY]).assertEqual('fixture-wrapped-user');
        expect(snapshot.values[KDF_PARAM_KEY]).assertEqual(source.values[KDF_PARAM_KEY]);

        // 数据库已提交而清理失败：重开后禁止再次读取或覆盖数据库。
        database.close();
        database = await CredentialDatabase.open(context, name);
        const reads = source.reads;
        source.failRead = true;
        source.failRemove = false;
        await LegacyCredentialMigration.run(database, source, true, 'wrong-owner');
        expect(source.reads).assertEqual(reads);
        expect(source.removals).assertEqual(LEGACY_CREDENTIAL_ALIASES.length);
        expect(database.readSync()!.legacyCleaned).assertTrue();
        expect(database.readSync()!.owner).assertEqual('fixture-owner');

        // 全部凭据无限于关键资产单条长度，UTF-8 与特殊字符保持不变。
        const longValues = database.readSync()!.values;
        longValues[ACCESS_TOKEN_KEY] = 'access.+/='.repeat(1600);
        longValues[REFRESH_TOKEN_KEY] = '刷新令牌.+/='.repeat(1000);
        longValues[TWO_FACTOR_TOKEN_KEY] = 'remember'.repeat(700);
        longValues[PRIVATE_KEY] = 'private'.repeat(1000);
        snapshot = await database.replace(longValues, true, 'fixture-owner', true);
        database.close();
        database = await CredentialDatabase.open(context, name);
        expect(JSON.stringify(database.readSync()!.values)).assertEqual(JSON.stringify(longValues));

        // 错误版本与无效刷新响应均保留整组旧值。
        await rejects(() => database.replace({}, true, 'bad', true, snapshot.revision - 1));
        expect(database.readSync()!.revision).assertEqual(snapshot.revision);
        await rejects(() => database.refresh(snapshot, {
          access_token: 'bad', refresh_token: 'bad', expires_in: 0, scope: '', token_type: 'Bearer'
        }));
        expect(database.readSync()!.values[ACCESS_TOKEN_KEY]).assertEqual(longValues[ACCESS_TOKEN_KEY]);

        // 短→长→短，刷新令牌轮换与其他解密材料一同可靠保存。
        await database.refresh(snapshot, {
          access_token: 'next'.repeat(3000), refresh_token: 'next-refresh', expires_in: 3600,
          scope: 'api offline_access', token_type: 'Bearer'
        });
        snapshot = database.readSync()!;
        expect(snapshot.values[REFRESH_TOKEN_KEY]).assertEqual('next-refresh');
        expect(snapshot.values[MASTER_KEY]).assertEqual('fixture-master');
        expect(Number(snapshot.values[TOKEN_EXPIRE_TIME_KEY]) > Date.now() / 1000).assertTrue();
        await database.refresh(snapshot, {
          access_token: 'short', refresh_token: 'short-refresh', expires_in: 3600,
          scope: 'api offline_access', token_type: 'Bearer'
        });
        expect(database.readSync()!.values[ACCESS_TOKEN_KEY]).assertEqual('short');
        expect(database.readSync()!.values[REFRESH_TOKEN_KEY]).assertEqual('short-refresh');

        // 已退出的会话不接受在途刷新；旧资产残留不会重新导入。
        snapshot = database.readSync()!;
        const empty: Record<string, string> = {};
        empty[EMAIL_KEY] = 'fixture@example.com';
        await database.replace(empty, false, '', false);
        await rejects(() => database.refresh(snapshot, {
          access_token: 'late', refresh_token: 'late', expires_in: 3600, scope: '', token_type: 'Bearer'
        }));
        const residual = fixtureSource();
        residual.failRead = true;
        await LegacyCredentialMigration.run(database, residual, true, 'fixture-owner');
        expect(database.readSync()!.loggedIn).assertFalse();
        expect(database.readSync()!.values[ACCESS_TOKEN_KEY] === undefined).assertTrue();
        expect(database.readSync()!.values[MASTER_KEY] === undefined).assertTrue();
        expect(residual.reads).assertEqual(0);
      } finally {
        database.close();
        await relationalStore.deleteRdbStore(context, name);
        CredentialDatabaseKey.remove(name);
      }

      // 旧版已退出但关键资产残留，只迁移记住的邮箱。
      const signedOutName = `credential_signedout_fixture_${Date.now()}.db`;
      const signedOut = await CredentialDatabase.open(context, signedOutName);
      try {
        const source = fixtureSource();
        await LegacyCredentialMigration.run(signedOut, source, false, 'fixture-owner');
        const record = signedOut.readSync()!;
        expect(record.loggedIn).assertFalse();
        expect(Object.keys(record.values).length).assertEqual(1);
        expect(record.values[EMAIL_KEY]).assertEqual('fixture@example.com');
        expect(record.legacyCleaned).assertTrue();
        expect(source.removals).assertEqual(LEGACY_CREDENTIAL_ALIASES.length);
      } finally {
        signedOut.close();
        await relationalStore.deleteRdbStore(context, signedOutName);
        CredentialDatabaseKey.remove(signedOutName);
      }
    });

    it('startupKeyReuseAndMissingKey', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.dreamist.homowarden', abilityName: 'EntryAbility' });
      const context = (await delegator.getCurrentTopAbility()).context;
      const name = `credential_key_fixture_${Date.now()}.db`;
      let database: CredentialDatabase | null = null;
      try {
        database = await CredentialDatabase.open(context, name);
        // 启动即创建密钥；登录前已可使用加密库。
        expect(CredentialDatabaseKey.databaseExists(context, name)).assertTrue();
        expect(CredentialDatabaseKey.read(name) !== null).assertTrue();
        await LegacyCredentialMigration.run(database, fixtureSource(), false, 'fixture-owner');
        const values: Record<string, string> = {};
        values[ACCESS_TOKEN_KEY] = 'fixture-access';
        values[REFRESH_TOKEN_KEY] = 'fixture-refresh';
        values[MASTER_KEY] = 'fixture-master';
        values[EMAIL_KEY] = 'fixture@example.com';
        await database.replace(values, true, 'fixture-owner', true);
        const key = CredentialDatabaseKey.read(name)!;
        const firstKey = new util.Base64Helper().encodeToStringSync(key);
        expect(key.length).assertEqual(32);
        key.fill(0);
        const query = keyQuery(name);
        query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
        const row = asset.querySync(query)[0];
        expect(row.get(asset.Tag.SYNC_TYPE) as number).assertEqual(asset.SyncType.NEVER);
        expect(row.get(asset.Tag.WRAP_TYPE) as number).assertEqual(asset.WrapType.NEVER);
        expect(row.get(asset.Tag.IS_PERSISTENT) as boolean).assertFalse();
        expect(row.get(asset.Tag.ACCESSIBILITY) as number).assertEqual(asset.Accessibility.DEVICE_UNLOCKED);
        (row.get(asset.Tag.SECRET) as Uint8Array).fill(0);
        // 刷新只更新令牌，密钥不变。
        await database.refresh(database.readSync()!, {
          access_token: 'refreshed', refresh_token: 'refreshed-refresh', expires_in: 3600,
          scope: '', token_type: 'Bearer'
        });
        const afterRefresh = CredentialDatabaseKey.read(name)!;
        expect(new util.Base64Helper().encodeToStringSync(afterRefresh)).assertEqual(firstKey);
        afterRefresh.fill(0);
        // 再次登录和退出都复用原密钥。
        await database.replace(values, true, 'fixture-owner', true);
        const second = CredentialDatabaseKey.read(name)!;
        expect(new util.Base64Helper().encodeToStringSync(second)).assertEqual(firstKey);
        second.fill(0);
        database.close();
        database = await CredentialDatabase.open(context, name);
        expect(database.readSync()!.values[MASTER_KEY]).assertEqual('fixture-master');
        const reopened = CredentialDatabaseKey.read(name)!;
        expect(new util.Base64Helper().encodeToStringSync(reopened)).assertEqual(firstKey);
        reopened.fill(0);
        database.close();
        database = null;

        // 错误密钥不能解密凭据库；失败不会自动重建。
        const wrongKey = await CryptoUtil.generateRandom(32);
        try {
          await rejects(async () => {
            const wrong = await relationalStore.getRdbStore(context, {
              name: name, securityLevel: relationalStore.SecurityLevel.S4, encrypt: true,
              allowRebuild: false, cryptoParam: { encryptionKey: wrongKey }
            });
            try {
              const result = wrong.querySqlSync('SELECT * FROM credentials');
              result.close();
            } finally {
              wrong.close();
            }
          });
        } finally {
          wrongKey.fill(0);
        }
        database = await CredentialDatabase.open(context, name);
        expect(database.readSync()!.values[MASTER_KEY]).assertEqual('fixture-master');
        database.close();
        database = null;

        // 损坏资产不是“未找到”，不允许替换原密钥。
        const corrupt: asset.AssetMap = new Map();
        corrupt.set(asset.Tag.SECRET, new Uint8Array(16));
        asset.updateSync(keyQuery(name), corrupt);
        await rejects(async () => { await CredentialDatabase.open(context, name); });
        expect((asset.querySync(query)[0].get(asset.Tag.SECRET) as Uint8Array).length).assertEqual(16);

        // 已有数据库但资产缺失：拒绝打开，不新建密钥，不触发旧凭据迁移。
        asset.removeSync(keyQuery(name));
        await rejects(async () => { await CredentialDatabase.open(context, name); });
        expect(CredentialDatabaseKey.read(name) === null).assertTrue();
      } finally {
        database?.close();
        await relationalStore.deleteRdbStore(context, name);
        // 此测试已删除临时密钥，finally 只处理提前失败留下的同名临时资产。
        CredentialDatabaseKey.remove(name);
      }
    });
  });
}
