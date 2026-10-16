import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';
import { DataPreferences } from '@abner/datastore';
import { AddCipherViewModel } from '../../../main/ets/viewmodel/AddCipherViewModel';
import { CipherDetailViewModel } from '../../../main/ets/viewmodel/CipherDetailViewModel';
import { VaultViewModel } from '../../../main/ets/viewmodel/VaultViewModel';
import { Cipher, CipherField, CipherUri } from '../../../main/ets/model/CipherModels';
import { getAllCiphers, getCipherById } from '../../../main/ets/network/CipherApi';
import { DatabaseUtil } from '../../../main/ets/utils/DatabaseUtil';
import { CredentialStore } from '../../../main/ets/utils/CredentialStore';
import { CryptoUtil } from '../../../main/ets/utils/CryptoUtil';
import { CipherItemType, CipherFieldType, DBTableName, FilterType, MASTER_KEY, USER_KEY } from '../../../main/ets/utils/Constants';

interface CheckResult {
  type: string;
  step: string;
  passed: boolean;
  assertions: number;
  failedFields: string[];
}

interface CrudReport {
  runId: string;
  startedAt: string;
  finishedAt: string;
  baselineCount: number;
  finalCount: number;
  assertions: number;
  results: CheckResult[];
}

interface HttpFailure {
  response?: HttpFailureResponse;
}

interface HttpFailureResponse {
  status?: number;
}

const TYPES: CipherItemType[] = [CipherItemType.LOGIN, CipherItemType.NOTE, CipherItemType.CARD, CipherItemType.IDENTITY];
const NAMES: string[] = ['', 'login', 'note', 'card', 'identity'];
const TABLES: string[] = [DBTableName.MAIN, DBTableName.KEYS, DBTableName.LOGINS, DBTableName.CARDS,
  DBTableName.IDENTITIES, DBTableName.NOTES, DBTableName.FIELDS];

export class CrudChecks {
  private context: Context;
  private key: string = '';
  private owned: Cipher[] = [];
  private baseline: Cipher[] = [];
  private current: CheckResult | null = null;
  private print: (message: string) => Promise<void>;
  private report: CrudReport = {
    runId: `${Date.now()}`, startedAt: new Date().toISOString(), finishedAt: '',
    baselineCount: 0, finalCount: 0, assertions: 0, results: []
  };

  constructor(context: Context, print: (message: string) => Promise<void>) {
    this.context = context;
    this.print = print;
  }

  private check(label: string, actual: string | number | boolean, expected: string | number | boolean): void {
    this.report.assertions++;
    if (this.current) {
      this.current.assertions++;
      if (actual !== expected) {
        this.current.passed = false;
        this.current.failedFields.push(label);
      }
    }
  }

  private async step(type: string, name: string, action: () => Promise<void>): Promise<void> {
    this.current = { type: type, step: name, passed: true, assertions: 0, failedFields: [] };
    try {
      await action();
    } catch (error) {
      this.current.passed = false;
      // Status and phase only; never serialize network errors, tokens, keys or existing vault data.
      const status = (error as HttpFailure).response?.status ?? 0;
      this.current.failedFields.push(`exception(status=${status})`);
    }
    this.report.results.push(this.current);
    await this.print(`CRUD_RESULT ${JSON.stringify(this.current)}`);
    this.current = null;
    this.saveReport();
  }

  private saveReport(): void {
    const file = fileIo.openSync(`${this.context.filesDir}/cipher-crud-report.json`,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try { fileIo.writeSync(file.fd, JSON.stringify(this.report, null, 2)); }
    finally { fileIo.closeSync(file); }
  }

  private fixture(type: CipherItemType, stage: string, empty: boolean = false): AddCipherViewModel {
    const form = new AddCipherViewModel();
    form.type = type;
    form.symmetricKey = this.key;
    form.name = `HW-CRUD-${this.report.runId}-${NAMES[type]}-${stage}`;
    form.notes = empty ? '' : `备注-${stage}-中文 🔐\nsecond line "quoted", &<>`;
    form.fields = empty ? [] : [
      { name: `文本-${stage}`, value: ` value ${stage}\n中文 & "quote" `, type: CipherFieldType.TEXT },
      { name: `隐藏-${stage}`, value: `00-${stage}-!@#$%+/=`, type: CipherFieldType.HIDE },
      { name: `布尔-${stage}`, value: stage === 'create' ? 'false' : 'true', type: CipherFieldType.BOOL }
    ];
    if (!empty) {
      form.loginItem = {
        username: `用户-${stage}@example.test`, password: `  Synthetic-${stage}-密碼!+/=  `,
        totp: stage === 'create' ? 'JBSWY3DPEHPK3PXP' : 'GEZDGNBVGY3TQOJQ',
        passwordRevisionDate: null, uris: []
      };
      form.loginUri = { uri: `https://example.test/${stage}?a=1&b=2`, uriChecksum: '' };
      form.cardItem = {
        cardholderName: `持卡人-${stage}`, brand: stage === 'create' ? 'Visa' : 'Mastercard',
        number: stage === 'create' ? '4111111111111111' : '5555555555554444',
        expMonth: stage === 'create' ? '09' : '12', expYear: stage === 'create' ? '2030' : '2035',
        code: stage === 'create' ? '007' : '009'
      };
      form.identityItem = {
        title: stage === 'create' ? 'Mr' : 'Dr', firstName: `名-${stage}`, middleName: `中-${stage}`,
        lastName: `姓-${stage}`, username: `identity-${stage}`, company: `公司-${stage}`,
        ssn: `000-${stage}`, passportNumber: `P-${stage}`, licenseNumber: `L-${stage}`,
        email: `${stage}@example.test`, phone: stage === 'create' ? '+85200000000' : '+85200000001',
        address1: `地址1-${stage}`, address2: `地址2-${stage}`, address3: `地址3-${stage}`,
        city: `城市-${stage}`, state: `省-${stage}`, postalCode: stage === 'create' ? '00123' : '00456',
        country: stage === 'create' ? 'HK' : 'CN'
      };
    }
    // Keep noteItem's constructor default: this also tests the actual add form's default note subtype.
    return form;
  }

  private expected(form: AddCipherViewModel): Cipher {
    const uris: CipherUri[] = form.loginUri.uri ? [{ uri: form.loginUri.uri, uriChecksum: '' }] : [];
    return {
      id: '', type: form.type, name: form.name, notes: form.notes || null, favorite: false, edit: true,
      folderId: null, organizationId: null, creationDate: '', revisionDate: '', deletedDate: null,
      reprompt: 0, fields: form.fields,
      login: form.type === CipherItemType.LOGIN ? {
        username: form.loginItem.username || '', password: form.loginItem.password || '',
        totp: form.loginItem.totp || '', passwordRevisionDate: null,
        uris: uris
      } : null,
      card: form.type === CipherItemType.CARD ? form.cardItem : null,
      identity: form.type === CipherItemType.IDENTITY ? form.identityItem : null,
      secureNote: form.type === CipherItemType.NOTE ? { type: CipherFieldType.TEXT } : null
    };
  }

  private values(cipher: Cipher): Record<string, string> {
    const result: Record<string, string> = {};
    result['name'] = cipher.name;
    result['notes'] = cipher.notes || '';
    result['type'] = `${cipher.type}`;
    if (cipher.type === CipherItemType.LOGIN) {
      result['login.username'] = cipher.login?.username || '';
      result['login.password'] = cipher.login?.password || '';
      result['login.totp'] = cipher.login?.totp || '';
      result['login.uris'] = JSON.stringify((cipher.login?.uris || []).map(uri => uri.uri));
    } else if (cipher.type === CipherItemType.CARD) {
      const card = cipher.card;
      result['card.cardholderName'] = card?.cardholderName || '';
      result['card.brand'] = card?.brand || '';
      result['card.number'] = card?.number || '';
      result['card.expMonth'] = card?.expMonth || '';
      result['card.expYear'] = card?.expYear || '';
      result['card.code'] = card?.code || '';
    } else if (cipher.type === CipherItemType.IDENTITY) {
      const identity = cipher.identity;
      result['identity.title'] = identity?.title || '';
      result['identity.firstName'] = identity?.firstName || '';
      result['identity.middleName'] = identity?.middleName || '';
      result['identity.lastName'] = identity?.lastName || '';
      result['identity.username'] = identity?.username || '';
      result['identity.company'] = identity?.company || '';
      result['identity.ssn'] = identity?.ssn || '';
      result['identity.passportNumber'] = identity?.passportNumber || '';
      result['identity.licenseNumber'] = identity?.licenseNumber || '';
      result['identity.email'] = identity?.email || '';
      result['identity.phone'] = identity?.phone || '';
      result['identity.address1'] = identity?.address1 || '';
      result['identity.address2'] = identity?.address2 || '';
      result['identity.address3'] = identity?.address3 || '';
      result['identity.city'] = identity?.city || '';
      result['identity.state'] = identity?.state || '';
      result['identity.postalCode'] = identity?.postalCode || '';
      result['identity.country'] = identity?.country || '';
    } else {
      result['secureNote.type'] = `${cipher.secureNote?.type}`;
    }
    result['fields.length'] = `${cipher.fields?.length || 0}`;
    (cipher.fields || []).forEach((field: CipherField, index: number) => {
      result[`fields.${index}.name`] = field.name || '';
      result[`fields.${index}.value`] = field.value || '';
      result[`fields.${index}.type`] = `${field.type}`;
    });
    return result;
  }

  private compare(label: string, actual: Cipher, expected: Cipher): void {
    const wanted = this.values(expected);
    const received = this.values(actual);
    Object.keys(wanted).forEach((key: string) => this.check(`${label}.${key}`, received[key], wanted[key]));
  }

  private async serverPlain(id: string): Promise<Cipher> {
    const cipher = await getCipherById(id);
    const key = await CryptoUtil.decryptCipherKey(cipher.key, this.key);
    cipher.name = await CryptoUtil.decryptField(cipher.name, key);
    cipher.notes = await CryptoUtil.decryptField(cipher.notes || '', key);
    if (cipher.login) {
      cipher.login.username = await CryptoUtil.decryptField(cipher.login.username || '', key);
      cipher.login.password = await CryptoUtil.decryptField(cipher.login.password || '', key);
      cipher.login.totp = await CryptoUtil.decryptField(cipher.login.totp || '', key);
      for (const uri of cipher.login.uris || []) {
        uri.uri = await CryptoUtil.decryptField(uri.uri, key);
        const checksum = await CryptoUtil.decryptField(uri.uriChecksum || '', key);
        this.check('server.uriChecksum', checksum, await CryptoUtil.doSha256(uri.uri));
      }
    }
    for (const details of [cipher.card, cipher.identity]) {
      if (details) {
        const values: Record<string, string | null> = JSON.parse(JSON.stringify(details));
        for (const name of Object.keys(values)) {
          values[name] = await CryptoUtil.decryptField(values[name] || '', key);
        }
        if (cipher.type === CipherItemType.CARD) { cipher.card = JSON.parse(JSON.stringify(values)); }
        else { cipher.identity = JSON.parse(JSON.stringify(values)); }
      }
    }
    for (const field of cipher.fields || []) {
      field.name = await CryptoUtil.decryptField(field.name || '', key);
      field.value = await CryptoUtil.decryptField(field.value || '', key);
    }
    return cipher;
  }

  private async local(id: string, sync: boolean): Promise<Cipher> {
    const vault = new VaultViewModel();
    if (!await vault.loadCiphers(sync)) { throw new Error('vault_read_failed'); }
    const cipher = vault.allCiphers.find(item => item.id === id);
    if (!cipher) { throw new Error('local_cipher_missing'); }
    const detail = new CipherDetailViewModel();
    detail.symmetricKey = this.key;
    return detail.getCipherDetail(cipher);
  }

  private async verify(id: string, expected: Cipher): Promise<void> {
    this.compare('local', await this.local(id, false), expected);
    this.compare('server', await this.serverPlain(id), expected);
    this.compare('synced', await this.local(id, true), expected);
    const vault = new VaultViewModel();
    await vault.loadCiphers(false);
    vault.filterCiphers(FilterType.ALL, expected.name);
    this.check('search.byName', vault.filteredCiphers.some(item => item.id === id), true);
    const filters: FilterType[] = [FilterType.ALL, FilterType.LOGINS, FilterType.NOTES, FilterType.CARDS, FilterType.IDENTITIES];
    vault.filterCiphers(filters[expected.type], expected.name);
    this.check('search.byType', vault.filteredCiphers.some(item => item.id === id), true);
  }

  private async edit(id: string, form: AddCipherViewModel, multipleUris: boolean = false): Promise<Cipher> {
    const cipher = await this.local(id, false);
    const detail = new CipherDetailViewModel();
    detail.symmetricKey = this.key;
    await detail.getCipherDetail(cipher);
    const expected = this.expected(form);
    if (multipleUris && expected.login) {
      expected.login.uris.push({ uri: 'https://second.example.test/中文', uriChecksum: '' });
    }
    cipher.name = expected.name;
    cipher.notes = expected.notes;
    cipher.login = expected.login;
    cipher.card = expected.card;
    cipher.identity = expected.identity;
    cipher.secureNote = expected.secureNote;
    cipher.fields = expected.fields;
    await detail.updateCipher(cipher);
    return expected;
  }

  private async assertDeleted(id: string): Promise<void> {
    const remote = await getAllCiphers();
    this.check('server.absent', (remote.ciphers || []).some(item => item.id === id), false);
    for (const table of TABLES) {
      const rows = await DatabaseUtil.getInstance().queryAllData(table);
      this.check(`database.${table}.absent`, rows.some(row => row.id === id || row.cipher_id === id), false);
    }
    let status = 0;
    try { await getCipherById(id); }
    catch (error) { status = (error as HttpFailure).response?.status ?? 0; }
    // Vaultwarden returns 400 for an unknown cipher; Bitwarden deployments may return 404.
    // Also require absence from /sync and every local table above, rather than relying on the status alone.
    this.check('server.GET.deleted.rejected', status === 400 || status === 404, true);
  }

  private async lifecycle(type: CipherItemType, empty: boolean): Promise<void> {
    const label = `${NAMES[type]}-${empty ? 'minimal' : 'full'}`;
    const form = this.fixture(type, 'create', empty);
    let id = '';
    let expected = this.expected(form);
    await this.step(label, 'create-all-fields-and-read', async () => {
      const created = await form.submitCreate();
      this.check('create.succeeded', created !== null, true);
      if (!created) { throw new Error('create_failed'); }
      id = created.id;
      this.owned.push(created);
      await this.verify(id, expected);
    });
    if (!id) { return; }
    await this.step(label, 'edit-all-fields-and-read', async () => {
      expected = await this.edit(id, this.fixture(type, 'edit'), true);
      await this.verify(id, expected);
    });
    await this.step(label, 'custom-field-add-remove', async () => {
      const changed = this.fixture(type, 'fields');
      changed.fields.push({ name: '新增文本', value: '新增值', type: CipherFieldType.TEXT });
      expected = await this.edit(id, changed);
      await this.verify(id, expected);
      changed.fields.splice(0, 1);
      expected = await this.edit(id, changed);
      await this.verify(id, expected);
    });
    await this.step(label, 'clear-optional-fields-and-read', async () => {
      expected = await this.edit(id, this.fixture(type, 'empty', true));
      await this.verify(id, expected);
    });
    await this.step(label, 'refill-all-fields-and-read', async () => {
      expected = await this.edit(id, this.fixture(type, 'refill'));
      await this.verify(id, expected);
    });
    await this.step(label, 'favorite-on-off', async () => {
      const detail = new CipherDetailViewModel();
      const cipher = await this.local(id, false);
      for (const favorite of [true, false]) {
        await detail.updateFavorite(cipher, favorite);
        const remote = await this.serverPlain(id);
        this.check('favorite.server', remote.favorite, favorite);
        this.check('favorite.local', (await this.local(id, true)).favorite, favorite);
        this.compare('favorite.contentPreserved', remote, expected);
      }
    });
    await this.step(label, 'soft-delete-and-restore', async () => {
      const detail = new CipherDetailViewModel();
      let cipher = await this.local(id, false);
      await detail.deleteCipher(cipher, false);
      this.check('softDelete.local', !!(await this.local(id, false)).deletedDate, true);
      this.check('softDelete.server', !!(await getCipherById(id)).deletedDate, true);
      const vault = new VaultViewModel();
      await vault.loadCiphers(true);
      vault.filterCiphers(FilterType.ALL, expected.name);
      this.check('softDelete.hiddenFromAll', vault.filteredCiphers.some(item => item.id === id), false);
      vault.filterCiphers(FilterType.DELETED, expected.name);
      this.check('softDelete.inRecycleBin', vault.filteredCiphers.some(item => item.id === id), true);
      cipher = await this.local(id, false);
      await detail.restoreCipher(cipher);
      this.check('restore.server', !!(await getCipherById(id)).deletedDate, false);
      await this.verify(id, expected);
    });
    await this.step(label, 'permanent-delete', async () => {
      await new CipherDetailViewModel().deleteCipher(await this.local(id, false), true);
      await this.assertDeleted(id);
    });
  }

  async run(): Promise<number> {
    await CredentialStore.initialize(this.context);
    CredentialStore.sessionSync();
    this.key = await CryptoUtil.decryptUserKey(CredentialStore.querySync(USER_KEY), CredentialStore.querySync(MASTER_KEY));
    await DatabaseUtil.init(this.context);
    await DatabaseUtil.getInstance().createTable();
    this.baseline = (await getAllCiphers()).ciphers || [];
    this.report.baselineCount = this.baseline.length;
    try {
      for (const type of TYPES) {
        await this.lifecycle(type, false);
        await this.lifecycle(type, true);
      }
    } finally {
      await this.step('safety', 'cleanup-only-this-run', async () => {
        const current = (await getAllCiphers()).ciphers || [];
        for (const cipher of this.owned) {
          if (this.baseline.some(original => original.id === cipher.id)) { throw new Error('baseline_id_guard'); }
          if (current.some(item => item.id === cipher.id)) {
            await new CipherDetailViewModel().deleteCipher(cipher, true);
          }
        }
        const vault = new VaultViewModel();
        this.check('final.sync', await vault.loadCiphers(true), true);
        const final = (await getAllCiphers()).ciphers || [];
        this.report.finalCount = final.length;
        this.check('baseline.countPreserved', final.length, this.baseline.length);
        for (const original of this.baseline) {
          const preserved = final.find(item => item.id === original.id);
          this.check('baseline.itemPreserved', !!preserved && JSON.stringify(preserved) === JSON.stringify(original), true);
        }
      });
      this.key = '';
      this.report.finishedAt = new Date().toISOString();
      this.saveReport();
    }
    const failed = this.report.results.filter(result => !result.passed).length;
    await this.print(`CRUD_SUMMARY run=${this.report.runId} checks=${this.report.results.length} ` +
      `failed=${failed} assertions=${this.report.assertions} baseline=${this.report.baselineCount} final=${this.report.finalCount}`);
    return failed;
  }
}

export async function runCipherCrudChecks(): Promise<number> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  // An explicit command-line flag prevents accidental live-account writes from an ordinary test run.
  if (abilityDelegatorRegistry.getArguments().parameters['-s liveCrud'] !== 'true') {
    throw new Error('Explicit liveCrud flag required');
  }
  await delegator.startAbility({ bundleName: 'com.dreamist.homowarden', abilityName: 'EntryAbility' });
  const ability = await delegator.getCurrentTopAbility();
  const prefs = DataPreferences.getInstance();
  prefs.init(ability.context);
  // DataPreferences.init uses a callback; wait for its default preference store to become available.
  for (let attempt = 0; attempt < 100; attempt++) {
    prefs.setPreferences();
    if (prefs.getPreferences()) { break; }
    await new Promise<void>(resolve => setTimeout(resolve, 20));
  }
  return new CrudChecks(ability.context, (message: string): Promise<void> => delegator.print(message + '\n')).run();
}
