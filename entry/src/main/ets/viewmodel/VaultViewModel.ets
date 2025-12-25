import { getAllCiphers } from '../network/CipherApi';
import { Cipher } from '../model/CipherModels';
import { Logger } from '@nzy/logger';
import { CipherItemType, DBTableName, FilterType, MASTER_KEY, USER_KEY } from '../utils/Constants';
import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { IBestDropdownMenuOption } from '@ibestservices/ibest-ui';
import { queryAssetSync } from '../utils/AssetUtil';
import { util } from '@kit.ArkTS';
import { CryptoUtil } from '../utils/CryptoUtil';

/**
 * 密码库ViewModel
 */
export class VaultViewModel {
  // 所有密码项
  allCiphers: Cipher[] = [];
  // 筛选后的密码项
  filteredCiphers: Cipher[] = [];
  // 加载状态
  isLoading: boolean = false;
  // 错误信息
  errorMessage: string = '';
  // 重新登录回调
  onReLoginRequired?: () => void;
  // 类型统计
  stats: CipherStats = {} as CipherStats;
  // 筛选菜单
  filterOptions: IBestDropdownMenuOption[] = [];
  // 对称密钥
  symmetricKey: string = '';

  /**
   * 加载所有密码项
   */
  async loadCiphers(): Promise<void> {
    try {
      this.isLoading = true;
      this.errorMessage = '';
      // 从服务器同步数据
      await this.syncCiphersFromServer();
    } catch (error) {
      Logger.error(`Failed to load ciphers: ${error}`);
      this.errorMessage = `加载密码项失败, 错误信息: ${JSON.stringify(error)}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 从服务器同步密码项数据
   */
  private async syncCiphersFromServer(): Promise<void> {
    try {
      Logger.debug('Starting to sync ciphers from server...');

      const response = await getAllCiphers();

      if (response && response.data && Array.isArray(response.data)) {
        Logger.debug(`Received ${response.data.length} ciphers from server`);

        // 启用数据库外键
        const enableForeignKeys = `PRAGMA foreign_keys = ON`;
        await DatabaseUtil.getInstance().executeSql(enableForeignKeys);

        // 删除数据库中所有密码项
        await DatabaseUtil.getInstance().deleteAllData(DBTableName.MAIN);

        // 将服务器数据保存到数据库
        for (const cipher of response.data) {
          await DatabaseUtil.getInstance().saveCipherToDatabase(cipher);
        }
      }
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Failed to sync ciphers from server: ${businessError.message}`);
      this.errorMessage = `获取密码项失败, 错误信息: ${businessError.message}`;

      // 检查是否是认证错误（需要重新登录）
      if (businessError.message.includes('401') || businessError.message.includes('403')) {
        this.errorMessage = '登录已过期，请重新登录';
        this.handleReLoginRequired();
      }
    } finally {
      // 从数据库加载并显示
      this.symmetricKey = await this.getSymmetricKey();
      const ciphersData = await DatabaseUtil.getInstance().queryAllData(DBTableName.MAIN);
      this.allCiphers = await this.buildCiphersFromData(ciphersData);
      this.filteredCiphers = this.allCiphers.filter(cipher => cipher.deletedDate == null);
      this.stats = await this.getCipherTypeStats();
      this.buildFilterOptions();

      Logger.debug(`Successfully synced ${this.allCiphers.length} ciphers from server`);
    }
  }

  /**
   * 处理需要重新登录的情况
   */
  private handleReLoginRequired(): void {
    Logger.debug('User needs to re-login');
    if (this.onReLoginRequired) {
      this.onReLoginRequired();
    }
  }

  /**
   * 从数据库数据构建密码项对象
   */
  private async buildCiphersFromData(ciphersData: relationalStore.ValuesBucket[]): Promise<Cipher[]> {
    const ciphers: Cipher[] = [];

    for (const cipherData of ciphersData) {
      const cipher: Cipher = {
        id: cipherData.id as string,
        type: cipherData.type as CipherItemType,
        name: cipherData.name as string,
        favorite: (cipherData.favorite as number) === 1,
        edit: (cipherData.edit as number) === 1,
        folderId: cipherData.folder_id as string || null,
        organizationId: cipherData.organization_id as string || null,
        creationDate: cipherData.creation_date as string,
        revisionDate: cipherData.revision_date as string,
        deletedDate: cipherData.deleted_date as string || null,
        notes: cipherData.notes as string || null,
        reprompt: cipherData.reprompt as number,
        login: null,
        identity: null,
        secureNote: null,
        card: null
      };
      // 格式化日期时间
      cipher.creationDate = this.formatDateTime(cipher.creationDate);
      cipher.revisionDate = this.formatDateTime(cipher.revisionDate);
      if (cipher.deletedDate != null) {
        cipher.deletedDate = this.formatDateTime(cipher.deletedDate);
      }
      // 解密基本字段
      cipher.name = await CryptoUtil.decryptField(cipher.name, this.symmetricKey);
      cipher.subtitle = await this.getSubtitle(cipher);
      cipher.notes = await CryptoUtil.decryptField(cipher.notes as string, this.symmetricKey);
      ciphers.push(cipher);
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
      return a.name.localeCompare(b.name, 'zh-CN');
    })

    return ciphers;
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
  filterCiphers(type: FilterType | string, searchText: string): void {
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

  /**
   * 刷新数据
   */
  async refresh(): Promise<void> {
    await this.loadCiphers();
  }

  /**
   * 获取各类型密码项数量统计
   */
  async getCipherTypeStats(): Promise<CipherStats> {
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
      const ciphersData = await DatabaseUtil.getInstance().queryAllData(DBTableName.MAIN);

      for (const cipherData of ciphersData) {
        if (cipherData.favorite as number === 1) {
          stats.favorite++;
        }

        if (cipherData.deleted_date != null) {
          stats.deleted++;
        } else {
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

      Logger.debug(`Cipher stats: ${JSON.stringify(stats)}`);
    } catch (error) {
      Logger.error(`Failed to get cipher stats: ${error}`);
      this.errorMessage = `获取密码项统计失败, 错误信息: ${JSON.stringify(error)}`;
      Promise.reject(error);
    }
    return stats;
  }

  // 构建筛选选项
  buildFilterOptions() {
    this.filterOptions = [];
    // 基础类型，包括全部、登录项、安全笔记、卡片、联系人、收藏、回收站
    this.filterOptions.push({ text: '全部(' + this.stats.total + ')', value: FilterType.ALL });
    this.filterOptions.push({ text: '登录(' + this.stats.login + ')', value: FilterType.LOGINS });
    this.filterOptions.push({ text: '笔记(' + this.stats.note + ')', value: FilterType.NOTES });
    this.filterOptions.push({ text: '支付卡(' + this.stats.card + ')', value: FilterType.CARDS });
    this.filterOptions.push({ text: '身份(' + this.stats.identity + ')', value: FilterType.IDENTITIES });
    this.filterOptions.push({ text: '收藏(' + this.stats.favorite + ')', value: FilterType.FAVORITE });
    this.filterOptions.push({ text: '回收站(' + this.stats.deleted + ')', value: FilterType.DELETED });
    // TODO: 添加文件夹筛选
  }

  // 格式化日期时间
  private formatDateTime(dateStr: string): string {
    if (!dateStr) {
      return '---';
    }
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }

  // 写入密码项副标题
  async getSubtitle(cipher: Cipher): Promise<string> {
    // 根据不同的项目类型返回对应的副标题
    if (cipher.type == CipherItemType.LOGIN) {
      const encUsername =
        DatabaseUtil.getInstance().querySingleData(DBTableName.LOGINS, 'cipher_id', cipher.id, 'username');
      if (encUsername != '') {
        const username = await CryptoUtil.decryptField(encUsername as string, this.symmetricKey);
        return username;
      }
    } else if (cipher.type == CipherItemType.CARD) {
      const encCardNumber =
        DatabaseUtil.getInstance().querySingleData(DBTableName.CARDS, 'cipher_id', cipher.id, 'number');
      if (encCardNumber && encCardNumber.toString().length > 5) {
        const cardNumber = await CryptoUtil.decryptField(encCardNumber as string, this.symmetricKey);
        return '*' + cardNumber.slice(-4);
      }
    } else if (cipher.type == CipherItemType.IDENTITY) {
      const encFirstName =
        DatabaseUtil.getInstance().querySingleData(DBTableName.IDENTITIES, 'cipher_id', cipher.id, 'first_name');
      const encLastName =
        DatabaseUtil.getInstance().querySingleData(DBTableName.IDENTITIES, 'cipher_id', cipher.id, 'last_name');
      if (encFirstName != '' && encLastName != '') {
        const firstName = await CryptoUtil.decryptField(encFirstName as string, this.symmetricKey);
        const lastName = await CryptoUtil.decryptField(encLastName as string, this.symmetricKey);
        return `${firstName} ${lastName}`;
      }
    }
    return this.getTypeName(cipher);
  }

  // 返回类型名称
  getTypeName(cipher: Cipher): string {
    switch (cipher.type) {
      case CipherItemType.LOGIN:
        return '登录';
      case CipherItemType.NOTE:
        return '安全笔记';
      case CipherItemType.CARD:
        return '卡片';
      case CipherItemType.IDENTITY:
        return '身份信息';
      default:
        return '未知';
    }
  }
}

export interface CipherStats {
  total: number,
  login: number,
  note: number,
  card: number,
  identity: number,
  favorite: number,
  deleted: number
}