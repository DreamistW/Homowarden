import { getAllCiphers } from '../network/CipherApi';
import { Cipher, CipherDisplayNameKind, CipherDisplaySubtitleKind } from '../model/CipherModels';
import { Logger } from '@nzy/logger';
import {
  CipherItemType,
  DBTableName,
  EMAIL_KEY,
  FilterType,
  KDF_PARAM_KEY,
  MASTER_KEY,
  USER_KEY
} from '../utils/Constants';
import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { AppDropdownOption } from '../model/AppUiModels';
import { queryAssetSync } from '../utils/AssetUtil';
import { util } from '@kit.ArkTS';
import { CryptoUtil } from '../utils/CryptoUtil';
import { PreloginResponse } from '../model/Prelogin';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { AppOptionFactory } from '../localization/AppOptionFactory';
import { AppText, AppTextKey } from '../localization/AppText';
import { LocaleUtil } from '../localization/LocaleUtil';
import { AutoLockUtil } from '../utils/AutoLockUtil';

/**
 * 密码库ViewModel
 */
export class VaultViewModel {
  // 所有实例共享同一同步 Promise，避免并发请求交错覆盖数据库。
  private static activeSyncPromise: Promise<boolean> | null = null;
  private static activeSyncGuards: Array<() => boolean> = [];
  private static activeDatabaseWritePromise: Promise<void> | null = null;
  private static syncGeneration: number = 0;
  private static syncBlocked: boolean = false;
  private static sessionActive: boolean = false;
  // 所有密码项
  allCiphers: Cipher[] = [];
  // 筛选后的密码项
  filteredCiphers: Cipher[] = [];
  // 加载状态
  isLoading: boolean = false;
  // 错误信息
  errorMessage: AppText | undefined = undefined;
  errorDetail: string = '';
  // 重新登录回调
  onReLoginRequired?: () => void;
  // 类型统计
  stats: CipherStats = {} as CipherStats;
  // 筛选菜单
  filterOptions: AppDropdownOption[] = [];
  // 对称密钥
  symmetricKey: string = '';

  /**
   * 加载所有密码项
   */
  async loadCiphers(forceSync: boolean = false): Promise<boolean> {
    try {
      this.errorMessage = undefined;
      this.errorDetail = '';

      if (forceSync) {
        this.isLoading = true;
        const syncResult = await this.syncCiphersFromServer();
        await this.loadCiphersFromDatabase();
        return syncResult;
      }

      await this.loadCiphersFromDatabase();
      return true;
    } catch (error) {
      Logger.error(`Failed to load ciphers: ${error}`);
      this.errorMessage = new AppText(AppTextKey.LOAD_FAILED);
      this.errorDetail = ErrorMessageUtil.getUserMessage(error, '');
      return false;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 从服务器同步密码项数据
   */
  private async syncCiphersFromServer(shouldApplyResult?: () => boolean): Promise<boolean> {
    if (VaultViewModel.syncBlocked) {
      return false;
    }
    if (VaultViewModel.activeSyncPromise) {
      if (shouldApplyResult) {
        VaultViewModel.activeSyncGuards.push(shouldApplyResult);
      }
      return await VaultViewModel.activeSyncPromise;
    }
    VaultViewModel.activeSyncGuards = [];
    if (shouldApplyResult) {
      VaultViewModel.activeSyncGuards.push(shouldApplyResult);
    }
    const generation = VaultViewModel.syncGeneration;
    const syncPromise = this.performSyncCiphersFromServer(generation);
    VaultViewModel.activeSyncPromise = syncPromise;
    try {
      return await syncPromise;
    } finally {
      if (VaultViewModel.activeSyncPromise === syncPromise) {
        VaultViewModel.activeSyncPromise = null;
        VaultViewModel.activeSyncGuards = [];
      }
    }
  }

  private static canApplySync(generation: number): boolean {
    if (VaultViewModel.syncBlocked || generation !== VaultViewModel.syncGeneration) {
      return false;
    }
    for (const guard of VaultViewModel.activeSyncGuards) {
      if (!guard()) {
        return false;
      }
    }
    return true;
  }

  static async prepareForLogout(): Promise<void> {
    VaultViewModel.sessionActive = false;
    VaultViewModel.syncBlocked = true;
    VaultViewModel.syncGeneration++;
    const writePromise = VaultViewModel.activeDatabaseWritePromise;
    if (writePromise) {
      try {
        await writePromise;
      } catch (error) {
        Logger.info(`Active vault database write stopped before logout: ${error}`);
      }
    }
  }

  static beginSession(): void {
    VaultViewModel.sessionActive = true;
    VaultViewModel.syncBlocked = false;
    VaultViewModel.syncGeneration++;
    AutoLockUtil.recordActivity();
  }

  static lockSession(): void {
    VaultViewModel.sessionActive = false;
  }

  static isSessionActive(): boolean {
    return VaultViewModel.sessionActive;
  }

  private async performSyncCiphersFromServer(generation: number): Promise<boolean> {
    try {
      Logger.info('Starting to sync ciphers from server...');

      const response = await getAllCiphers();
      // 调用方可用修订号判定结果是否已被本地编辑淘汰。
      if (!VaultViewModel.canApplySync(generation)) {
        Logger.info('Skip stale vault sync response');
        return false;
      }

      if (response && response.ciphers && Array.isArray(response.ciphers)) {
        Logger.info(`Received ${response.ciphers.length} ciphers from server`);

        // 全量替换必须置于同一事务，任何条目失败都回滚旧密码库。
        const enableForeignKeys = `PRAGMA foreign_keys = ON`;
        await DatabaseUtil.getInstance().executeSql(enableForeignKeys);
        if (!VaultViewModel.canApplySync(generation)) {
          Logger.info('Skip stale vault sync database write');
          return false;
        }

        const writePromise = this.replaceVaultDatabase(response.ciphers, generation);
        VaultViewModel.activeDatabaseWritePromise = writePromise;
        try {
          await writePromise;
        } finally {
          if (VaultViewModel.activeDatabaseWritePromise === writePromise) {
            VaultViewModel.activeDatabaseWritePromise = null;
          }
        }
      }
      return true;
    } catch (error) {
      const businessError = error as BusinessError;
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Failed to sync ciphers from server: ${errorMessage}`);
      this.errorMessage = new AppText(AppTextKey.LOAD_FAILED);
      this.errorDetail = ErrorMessageUtil.getUserMessage(error as Object, '');

      // 检查是否是认证错误（需要重新登录）
      if (businessError.message.includes('401') || businessError.message.includes('403')) {
        this.errorMessage = new AppText(AppTextKey.AUTH_EXPIRED);
        this.handleReLoginRequired();
      }
      return false;
    }
  }

  private async replaceVaultDatabase(ciphers: Cipher[], generation: number): Promise<void> {
    await DatabaseUtil.getInstance().beginTransaction();
    try {
      await DatabaseUtil.getInstance().deleteAllData(DBTableName.MAIN);
      for (const cipher of ciphers) {
        if (!VaultViewModel.canApplySync(generation)) {
          throw new Error('Vault sync became stale');
        }
        await DatabaseUtil.getInstance().saveCipherToDatabase(cipher);
      }
      if (!VaultViewModel.canApplySync(generation)) {
        throw new Error('Vault sync became stale');
      }
      await DatabaseUtil.getInstance().commitTransaction();
    } catch (error) {
      try {
        await DatabaseUtil.getInstance().rollBackTransaction();
      } catch (rollbackError) {
        Logger.error(`Failed to roll back cipher sync transaction: ${rollbackError}`);
      }
      throw new Error(`Cipher sync transaction failed: ${error}`);
    }
  }

  private async loadCiphersFromDatabase() {
    await DatabaseUtil.getInstance().createTable();
    this.symmetricKey = await this.getSymmetricKey();
    const ciphersData = await DatabaseUtil.getInstance().queryAllData(DBTableName.MAIN);
    const cipherKeysData = await DatabaseUtil.getInstance().queryAllData(DBTableName.KEYS);
    const loginData = await DatabaseUtil.getInstance().queryAllData(DBTableName.LOGINS);
    const cardData = await DatabaseUtil.getInstance().queryAllData(DBTableName.CARDS);
    const identityData = await DatabaseUtil.getInstance().queryAllData(DBTableName.IDENTITIES);
    const cipherKeysById = this.buildRowsByCipherId(cipherKeysData);
    const loginsById = this.buildRowsByCipherId(loginData);
    const cardsById = this.buildRowsByCipherId(cardData);
    const identitiesById = this.buildRowsByCipherId(identityData);
    this.allCiphers = await this.buildCiphersFromData(ciphersData, cipherKeysById, loginsById, cardsById,
      identitiesById);
    this.filteredCiphers = this.allCiphers.filter(cipher => cipher.deletedDate == null);
    this.stats = await this.getCipherTypeStats(ciphersData);
    this.buildFilterOptions();

    Logger.info(`Loaded ${this.allCiphers.length} ciphers from database`);
  }

  /**
   * 处理需要重新登录的情况
   */
  private handleReLoginRequired(): void {
    Logger.info('User needs to re-login');
    if (this.onReLoginRequired) {
      this.onReLoginRequired();
    }
  }

  /**
   * 后台同步数据：不显示全屏 loading
   */
  async syncCiphersInBackground(shouldApplyResult?: () => boolean): Promise<boolean> {
    try {
      this.errorMessage = undefined;
      const didApplySync = await this.syncCiphersFromServer(shouldApplyResult);
      if (!didApplySync) {
        if (shouldApplyResult && !shouldApplyResult()) {
          Logger.info('Background sync response was stale and ignored');
          return true;
        }
        return false;
      }
      if (shouldApplyResult && !shouldApplyResult()) {
        Logger.info('Skip stale vault reload after sync');
        return true;
      }
      await this.loadCiphersFromDatabase();
      Logger.info('Background sync completed');
      return true;
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Background sync failed: ${errorMessage}`);
      this.errorMessage = new AppText(AppTextKey.LOAD_FAILED);
      return false;
    }
  }

  /**
   * 从数据库数据构建密码项对象
   */
  private async buildCiphersFromData(ciphersData: relationalStore.ValuesBucket[],
    cipherKeysById: Map<string, relationalStore.ValuesBucket>,
    loginsById: Map<string, relationalStore.ValuesBucket>, cardsById: Map<string, relationalStore.ValuesBucket>,
    identitiesById: Map<string, relationalStore.ValuesBucket>): Promise<Cipher[]> {
    const ciphers: Cipher[] = [];
    const batchSize: number = 16;
    for (let start: number = 0; start < ciphersData.length; start += batchSize) {
      const end: number = Math.min(start + batchSize, ciphersData.length);
      const batchData: relationalStore.ValuesBucket[] = ciphersData.slice(start, end);
      const batchCiphers: Cipher[] = await Promise.all(batchData.map(
        async (cipherData: relationalStore.ValuesBucket): Promise<Cipher> => {
          return await this.buildCipherFromData(cipherData, cipherKeysById, loginsById, cardsById, identitiesById);
        }
      ));
      ciphers.push(...batchCiphers);
    }

    ciphers.sort((a: Cipher, b: Cipher) => {
      if (!a.name && !b.name) {
        return 0;
      }
      if (!a.name) {
        return 1;
      }
      if (!b.name) {
        return -1;
      }
      return a.name.localeCompare(b.name, LocaleUtil.getLanguage());
    })

    return ciphers;
  }

  private async buildCipherFromData(cipherData: relationalStore.ValuesBucket,
    cipherKeysById: Map<string, relationalStore.ValuesBucket>,
    loginsById: Map<string, relationalStore.ValuesBucket>, cardsById: Map<string, relationalStore.ValuesBucket>,
    identitiesById: Map<string, relationalStore.ValuesBucket>): Promise<Cipher> {
      const rawRevisionDate = cipherData.revision_date as string;
      const cipherId = cipherData.id as string;
      const keyData = cipherKeysById.get(cipherId);
      const loginData = loginsById.get(cipherId);
      const cipher: Cipher = {
        id: cipherId,
        type: cipherData.type as CipherItemType,
        name: cipherData.name as string,
        favorite: (cipherData.favorite as number) === 1,
        edit: (cipherData.edit as number) === 1,
        folderId: cipherData.folder_id as string || null,
        organizationId: cipherData.organization_id as string || null,
        creationDate: cipherData.creation_date as string,
        revisionDate: rawRevisionDate,
        lastKnownRevisionDate: rawRevisionDate,
        deletedDate: cipherData.deleted_date as string || null,
        notes: cipherData.notes as string || null,
        key: keyData ? keyData.encrypted_key as string : null,
        encryptedFor: keyData ? keyData.encrypted_for as string || null : null,
        reprompt: cipherData.reprompt as number,
        login: null,
        identity: null,
        secureNote: null,
        card: null
      };
      cipher.hasTotp = cipher.type === CipherItemType.LOGIN &&
        loginData?.totp !== null && loginData?.totp !== undefined && loginData.totp.toString().length > 0;
      cipher.displayNameKind = CipherDisplayNameKind.USER_VALUE;
      cipher.displaySubtitleKind = CipherDisplaySubtitleKind.USER_VALUE;
      try {
        const cipherKey = await CryptoUtil.decryptCipherKey(cipher.key, this.symmetricKey);
        cipher.name = await CryptoUtil.decryptField(cipher.name, cipherKey);
        cipher.subtitle = await this.getSubtitle(cipher, cipherKey, loginsById, cardsById, identitiesById);
        if (!cipher.subtitle) {
          cipher.displaySubtitleKind = this.getTypeSubtitleKind(cipher.type);
        }
        cipher.notes = await CryptoUtil.decryptField(cipher.notes as string, cipherKey);
      } catch (error) {
        Logger.error(`Failed to decrypt cipher ${cipher.id}: ${error}`);
        cipher.name = '';
        cipher.subtitle = '';
        // 解密失败文案由 UI 按当前语言解析，不能写回为用户字段。
        cipher.displayNameKind = CipherDisplayNameKind.DECRYPTION_FAILED;
        cipher.displaySubtitleKind = CipherDisplaySubtitleKind.DECRYPTION_FAILED;
        cipher.notes = null;
        cipher.edit = false;
      }
      return cipher;
  }

  private buildRowsByCipherId(rows: relationalStore.ValuesBucket[]): Map<string, relationalStore.ValuesBucket> {
    const rowsById = new Map<string, relationalStore.ValuesBucket>();
    for (const row of rows) {
      const cipherId = row.cipher_id;
      if (cipherId !== null && cipherId !== undefined) {
        rowsById.set(cipherId.toString(), row);
      }
    }
    return rowsById;
  }

  // 获得对称密钥
  private async getSymmetricKey(): Promise<string> {
    const masterKey = queryAssetSync(MASTER_KEY);
    const masterKeyBytes = new util.Base64Helper().decodeSync(masterKey);
    const encKey = await CryptoUtil.deriveKeyHKDF(masterKeyBytes, 'enc');
    const macKey = await CryptoUtil.deriveKeyHKDF(masterKeyBytes, 'mac');
    const encKeyBytes = new util.Base64Helper().decodeSync(encKey);
    const userKey = queryAssetSync(USER_KEY);
    // MAC验证
    const macKeyBytes = new util.Base64Helper().decodeSync(macKey);
    const macResult = await CryptoUtil.verifyHMAC(userKey, macKeyBytes);
    if (macResult) {
      const symKey = await CryptoUtil.decryptAESCBC(userKey, encKeyBytes);
      return symKey;
    } else {
      throw new Error(`MAC verification failed`);
    }
  }

  /**
   * 筛选密码项
   * @param type 筛选类型：all, favorites, folders
   * @param searchText 搜索文本
   */
  filterCiphers(type: FilterType, searchText: string): void {
    let filtered = [...this.allCiphers];

    // 按类型筛选
    switch (type) {
      case FilterType.ALL:
        filtered = filtered.filter(cipher => cipher.deletedDate == null);
        break;
      case FilterType.LOGINS:
        filtered = filtered.filter(cipher => cipher.type == CipherItemType.LOGIN && cipher.deletedDate == null);
        break;
      case FilterType.NOTES:
        filtered = filtered.filter(cipher => cipher.type == CipherItemType.NOTE && cipher.deletedDate == null);
        break;
      case FilterType.CARDS:
        filtered = filtered.filter(cipher => cipher.type == CipherItemType.CARD && cipher.deletedDate == null);
        break;
      case FilterType.IDENTITIES:
        filtered = filtered.filter(cipher => cipher.type == CipherItemType.IDENTITY && cipher.deletedDate == null);
        break;
      case FilterType.FAVORITE:
        filtered = filtered.filter(cipher => cipher.favorite && cipher.deletedDate == null);
        break;
      case FilterType.DELETED:
        filtered = filtered.filter(cipher => cipher.deletedDate != null);
        break;
      default:
        break;
    }

    // 按搜索文本筛选
    if (searchText && searchText.trim()) {
      const searchLower = searchText.toLowerCase();
      filtered = filtered.filter(cipher => {
        // 搜索名称
        if (cipher.name.toLowerCase().includes(searchLower)) {
          return true;
        }

        // 搜索用户名（如果是登录类型）
        if (cipher.login && cipher.login.username &&
          cipher.login.username.toLowerCase().includes(searchLower)) {
          return true;
        }

        // 搜索备注
        if (cipher.notes && cipher.notes.toLowerCase().includes(searchLower)) {
          return true;
        }

        return false;
      });
    }

    this.filteredCiphers = filtered;
  }

  applyLocalCipherChange(cipher: Cipher, filterType: FilterType, searchText: string): void {
    if (!cipher || !cipher.id) {
      return;
    }

    const changedCipher = this.buildListCipherFromPlainCipher(cipher);
    const ciphers = this.allCiphers.filter(item => item.id !== changedCipher.id);
    ciphers.push(changedCipher);
    this.allCiphers = this.sortCiphersByName(ciphers);
    this.stats = this.getCipherTypeStatsFromCiphers(this.allCiphers);
    this.buildFilterOptions();
    this.filterCiphers(filterType, searchText);
  }

  applyLocalCipherDeletion(cipherId: string, filterType: FilterType, searchText: string): void {
    if (!cipherId) {
      return;
    }

    this.allCiphers = this.sortCiphersByName(this.allCiphers.filter(item => item.id !== cipherId));
    this.stats = this.getCipherTypeStatsFromCiphers(this.allCiphers);
    this.buildFilterOptions();
    this.filterCiphers(filterType, searchText);
  }

  /**
   * 刷新数据
   */
  async refresh(): Promise<void> {
    await this.loadCiphers(true);
  }

  /**
   * 获取各类型密码项数量统计
   */
  async getCipherTypeStats(data: relationalStore.ValuesBucket[]): Promise<CipherStats> {
    let stats: CipherStats = {
      total: 0,
      login: 0,
      note: 0,
      card: 0,
      identity: 0,
      favorite: 0,
      deleted: 0
    };
    try {
      for (const cipherData of data) {
        if (cipherData.deleted_date != null) {
          stats.deleted++;
        } else {
          if (cipherData.favorite as number === 1) {
            stats.favorite++;
          }
          stats.total++;
          switch (cipherData.type as number) {
            case CipherItemType.LOGIN:
              stats.login++;
              break;
            case CipherItemType.NOTE:
              stats.note++;
              break;
            case CipherItemType.CARD:
              stats.card++;
              break;
            case CipherItemType.IDENTITY:
              stats.identity++;
              break;
          }
        }
      }

      Logger.info(`Cipher stats: ${JSON.stringify(stats)}`);
    } catch (error) {
      Logger.error(`Failed to get cipher stats: ${error}`);
      this.errorMessage = new AppText(AppTextKey.LOAD_FAILED);
      throw new Error(ErrorMessageUtil.getUserMessage(error, 'Failed to get cipher stats'));
    }
    return stats;
  }

  private getCipherTypeStatsFromCiphers(ciphers: Cipher[]): CipherStats {
    let stats: CipherStats = {
      total: 0,
      login: 0,
      note: 0,
      card: 0,
      identity: 0,
      favorite: 0,
      deleted: 0
    };

    for (const cipher of ciphers) {
      if (cipher.deletedDate != null) {
        stats.deleted++;
        continue;
      }
      if (cipher.favorite) {
        stats.favorite++;
      }
      stats.total++;
      switch (cipher.type) {
        case CipherItemType.LOGIN:
          stats.login++;
          break;
        case CipherItemType.NOTE:
          stats.note++;
          break;
        case CipherItemType.CARD:
          stats.card++;
          break;
        case CipherItemType.IDENTITY:
          stats.identity++;
          break;
      }
    }

    return stats;
  }

  private buildListCipherFromPlainCipher(cipher: Cipher): Cipher {
    const identityFirstName: string = cipher.identity?.firstName ?? '';
    const identityLastName: string = cipher.identity?.lastName ?? '';
    const subtitle: string = this.getPlainSubtitle(cipher);
    // 本地变更传入明文对象；列表副本移除详情结构，避免与加密数据库模型混用。
    return {
      id: cipher.id,
      type: cipher.type,
      name: cipher.name,
      favorite: cipher.favorite,
      edit: cipher.edit,
      viewPassword: cipher.viewPassword,
      folderId: cipher.folderId,
      organizationId: cipher.organizationId,
      creationDate: cipher.creationDate,
      revisionDate: cipher.revisionDate,
      lastKnownRevisionDate: cipher.lastKnownRevisionDate,
      deletedDate: cipher.deletedDate,
      archivedDate: cipher.archivedDate || null,
      notes: cipher.notes,
      login: null,
      card: null,
      identity: null,
      secureNote: null,
      sshKey: null,
      bankAccount: null,
      driversLicense: null,
      passport: null,
      fields: [],
      collectionIds: cipher.collectionIds || [],
      passwordHistory: null,
      attachments: null,
      attachments2: null,
      key: cipher.key || null,
      encryptedFor: cipher.encryptedFor || null,
      reprompt: cipher.reprompt,
      subtitle: subtitle,
      displayNameKind: CipherDisplayNameKind.USER_VALUE,
      displaySubtitleKind: subtitle.length > 0 ? CipherDisplaySubtitleKind.USER_VALUE :
        this.getTypeSubtitleKind(cipher.type),
      identityFirstName: identityFirstName,
      identityLastName: identityLastName,
      hasTotp: cipher.hasTotp || (cipher.type === CipherItemType.LOGIN && !!cipher.login?.totp)
    };
  }

  private getPlainSubtitle(cipher: Cipher): string {
    if (cipher.type == CipherItemType.LOGIN && cipher.login?.username) {
      return cipher.login.username;
    }
    if (cipher.type == CipherItemType.CARD && cipher.card?.number) {
      return cipher.card.number.length > 4 ? '*' + cipher.card.number.slice(-4) : cipher.card.number;
    }
    if (cipher.type == CipherItemType.IDENTITY) {
      const firstName = cipher.identity?.firstName || '';
      const lastName = cipher.identity?.lastName || '';
      return LocaleUtil.formatIdentityName(firstName, lastName);
    }
    return '';
  }

  private sortCiphersByName(ciphers: Cipher[]): Cipher[] {
    ciphers.sort((a: Cipher, b: Cipher) => {
      if (!a.name && !b.name) {
        return 0;
      }
      if (!a.name) {
        return 1;
      }
      if (!b.name) {
        return -1;
      }
      return a.name.localeCompare(b.name, LocaleUtil.getLanguage());
    });
    return ciphers;
  }

  /** 根据当前统计值重建本地化筛选选项。 */
  buildFilterOptions() {
    this.filterOptions = AppOptionFactory.vaultFilters(this.stats.total, this.stats.login, this.stats.note,
      this.stats.card, this.stats.identity, this.stats.favorite, this.stats.deleted);
  }

  /** 解密列表副标题，并保留身份姓名分量供语言切换时重排。 */
  async getSubtitle(cipher: Cipher, cipherKey: string,
    loginsById: Map<string, relationalStore.ValuesBucket>, cardsById: Map<string, relationalStore.ValuesBucket>,
    identitiesById: Map<string, relationalStore.ValuesBucket>): Promise<string> {
    // 根据不同的项目类型返回对应的副标题
    if (cipher.type == CipherItemType.LOGIN) {
      const loginRow = loginsById.get(cipher.id);
      const encUsername = loginRow ? loginRow.username : '';
      if (encUsername != '') {
        const username = await CryptoUtil.decryptField(encUsername as string, cipherKey);
        return username;
      }
    } else if (cipher.type == CipherItemType.CARD) {
      const cardRow = cardsById.get(cipher.id);
      const encCardNumber = cardRow ? cardRow.number : '';
      if (encCardNumber && encCardNumber.toString().length > 5) {
        const cardNumber = await CryptoUtil.decryptField(encCardNumber as string, cipherKey);
        return '*' + cardNumber.slice(-4);
      }
    } else if (cipher.type == CipherItemType.IDENTITY) {
      const identityRow = identitiesById.get(cipher.id);
      const encFirstName = identityRow ? identityRow.first_name : '';
      const encLastName = identityRow ? identityRow.last_name : '';
      if (encFirstName != '' || encLastName != '') {
        const firstName = encFirstName != '' ? await CryptoUtil.decryptField(encFirstName as string, cipherKey) : '';
        const lastName = encLastName != '' ? await CryptoUtil.decryptField(encLastName as string, cipherKey) : '';
        cipher.identityFirstName = firstName;
        cipher.identityLastName = lastName;
        return LocaleUtil.formatIdentityName(firstName, lastName);
      }
    }
    return '';
  }

  /** 返回无用户副标题时应展示的本地化类型语义。 */
  private getTypeSubtitleKind(type: CipherItemType): CipherDisplaySubtitleKind {
    switch (type) {
      case CipherItemType.LOGIN:
        return CipherDisplaySubtitleKind.LOGIN;
      case CipherItemType.NOTE:
        return CipherDisplaySubtitleKind.NOTE;
      case CipherItemType.CARD:
        return CipherDisplaySubtitleKind.CARD;
      case CipherItemType.IDENTITY:
        return CipherDisplaySubtitleKind.IDENTITY;
      default:
        return CipherDisplaySubtitleKind.UNKNOWN;
    }
  }

  /** 刷新所有依赖语言环境的派生字段和筛选选项。 */
  refreshLocale(): void {
    for (const cipher of this.allCiphers) {
      if (cipher.type === CipherItemType.IDENTITY &&
        cipher.displaySubtitleKind === CipherDisplaySubtitleKind.USER_VALUE &&
        cipher.identityFirstName !== undefined && cipher.identityLastName !== undefined) {
        cipher.subtitle = LocaleUtil.formatIdentityName(cipher.identityFirstName, cipher.identityLastName);
      }
    }
    this.allCiphers = this.sortCiphersByName([...this.allCiphers]);
    this.buildFilterOptions();
  }

  /** 使用持久化 KDF 参数重新派生主密钥，验证受保护条目的访问权限。 */
  async verifyMasterPassword(passwordInput: string): Promise<boolean> {
    if (!passwordInput || passwordInput.length === 0) {
      this.errorMessage = new AppText(AppTextKey.MASTER_PASSWORD_REQUIRED);
      return false;
    }

    try {
      // 获取存储的 KDF 参数
      const kdfParamStr: string = queryAssetSync(KDF_PARAM_KEY);
      if (!kdfParamStr) {
        this.errorMessage = new AppText(AppTextKey.PARAMETERS_FAILED);
        return false;
      }

      const kdfParams: PreloginResponse = JSON.parse(kdfParamStr);
      const storedMasterKey = queryAssetSync(MASTER_KEY);
      const email = queryAssetSync(EMAIL_KEY);

      if (!storedMasterKey) {
        this.errorMessage = new AppText(AppTextKey.PARAMETERS_FAILED);
        return false;
      }

      // 使用输入的密码重新派生主密钥
      let derivedMasterKey: string = '';
      const salt = email.trim().toLowerCase() || '';

      if (kdfParams.kdf === 0) {
        // PBKDF2
        derivedMasterKey = await CryptoUtil.deriveKeyPBKDF2(
          passwordInput,
          salt,
          kdfParams.kdfIterations || 100000,
          32
        );
      } else if (kdfParams.kdf === 1) {
        // Argon2id
        derivedMasterKey = await CryptoUtil.deriveKeyArgon2id(
          passwordInput,
          salt,
          kdfParams.kdfIterations || 2,
          kdfParams.kdfMemory || 16,
          kdfParams.kdfParallelism || 1,
          32
        );
      } else {
        this.errorMessage = new AppText(AppTextKey.KDF_UNSUPPORTED);
        return false;
      }

      // 验证派生的主密钥是否与存储的匹配
      if (derivedMasterKey === storedMasterKey) {
        return true;
      } else {
        this.errorMessage = new AppText(AppTextKey.MASTER_PASSWORD_WRONG);
        return false;
      }
    } catch (error) {
      Logger.error(`Master password verification failed: ${error}`);
      this.errorMessage = new AppText(AppTextKey.VERIFICATION_FAILED);
      return false;
    }
  }
}

/** 密码库筛选菜单使用的条目数量统计。 */
export interface CipherStats {
  total: number,
  login: number,
  note: number,
  card: number,
  identity: number,
  favorite: number,
  deleted: number
}
