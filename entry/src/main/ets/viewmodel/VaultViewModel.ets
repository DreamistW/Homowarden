import { getAllCiphers } from '../network/CipherApi.ets';
import { Cipher } from '../model/CipherModels.ets';
import { Logger } from '@nzy/logger';
import { CipherItemType, DBTableName, FilterType } from '../utils/Constants';
import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { IBestDropdownMenuOption } from '@ibestservices/ibest-ui';

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

  /**
   * 加载所有密码项
   */
  async loadCiphers(): Promise<void> {
    try {
      this.isLoading = true;
      this.errorMessage = '';

      // 从数据库加载密码项
      const ciphersData = await DatabaseUtil.getInstance().queryAllData(DBTableName.MAIN);
      this.allCiphers = await this.buildCiphersFromData(ciphersData);
      this.filteredCiphers = this.allCiphers.filter(cipher => cipher.deletedDate == null);
      this.stats = await this.getCipherTypeStats();
      this.buildFilterOptions();

      Logger.debug(`Loaded ${this.allCiphers.length} ciphers from database`);

      // 异步从服务器同步数据
      this.syncCiphersFromServer();
    } catch (error) {
      Logger.error(`Failed to load ciphers: ${error}`);
      this.errorMessage = '加载密码项失败';
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

        // 重新从数据库加载并显示
        const ciphersData = await DatabaseUtil.getInstance().queryAllData(DBTableName.MAIN);
        this.allCiphers = await this.buildCiphersFromData(ciphersData);
        this.filteredCiphers = this.allCiphers.filter(cipher => cipher.deletedDate == null);
        this.stats = await this.getCipherTypeStats();

        Logger.debug(`Successfully synced ${this.allCiphers.length} ciphers from server`);
      }
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Failed to sync ciphers from server: ${businessError.message}`);

      // 检查是否是认证错误（需要重新登录）
      if (businessError.message.includes('401') || businessError.message.includes('403')) {
        this.errorMessage = '登录已过期，请重新登录';
        this.handleReLoginRequired();
      }
      // 其他错误不处理，保持本地数据显示
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
        revisionDate: cipherData.revision_date as string || null,
        deletedDate: cipherData.deleted_date as string || null,
        notes: cipherData.notes as string || null,
        reprompt: cipherData.reprompt as number
      };

      // 根据类型加载详细信息
      // if (cipher.type === CipherItemType.LOGIN) {
      //   cipher.login = await this.getCipherLogin(cipher.id!);
      // } else if (cipher.type === CipherItemType.CARD) {
      //   cipher.card = await this.getCipherCard(cipher.id!);
      // } else if (cipher.type === CipherItemType.IDENTITY) {
      //   cipher.identity = await this.getCipherIdentity(cipher.id!);
      // } else if (cipher.type === CipherItemType.NOTE) {
      //   cipher.secureNote = await this.getCipherSecureNote(cipher.id!);
      // }
      //
      // // 加载自定义字段
      // cipher.fields = await this.getCipherFields(cipher.id!);

      ciphers.push(cipher);
    }

    return ciphers;
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
    const stats: CipherStats = {} as CipherStats;
    try {
      const ciphersData = await DatabaseUtil.getInstance().queryAllData(DBTableName.MAIN);

      for (const cipherData of ciphersData) {
        const type = cipherData.type as number;
        const favorite = cipherData.favorite as number;
        const deleted = cipherData.deletedDate;

        stats.total++;

        if (favorite === 1) {
          stats.favorite++;
        }

        if (deleted != null) {
          stats.deleted++;
        }

        switch (type) {
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

      Logger.debug(`Cipher stats: ${JSON.stringify(stats)}`);
    } catch (error) {
      Logger.error(`Failed to get cipher stats: ${error}`);
      Promise.reject(error);
    }
    return stats;
  }

  // 构建筛选选项
  buildFilterOptions() {
    this.filterOptions = [];
    // 基础类型，包括全部、登录项、安全笔记、卡片、联系人、收藏、回收站
    this.filterOptions.push({ text: '全部', value: FilterType.ALL });
    this.filterOptions.push({ text: '登录项', value: FilterType.LOGINS });
    this.filterOptions.push({ text: '笔记', value: FilterType.NOTES });
    this.filterOptions.push({ text: '卡片', value: FilterType.CARDS });
    this.filterOptions.push({ text: '联系人', value: FilterType.IDENTITIES });
    this.filterOptions.push({ text: '收藏', value: FilterType.FAVORITE });
    this.filterOptions.push({ text: '回收站', value: FilterType.DELETED });
    // TODO: 添加文件夹筛选
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