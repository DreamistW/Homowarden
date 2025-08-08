import { getAllCiphers, updateCipher } from '../network/CipherApi.ets';
import { Cipher, CipherField } from '../model/CipherModels.ets';
import { Logger } from '@nzy/logger';
import { CipherItemType, DBTableName } from '../utils/Constants';
import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { DatabaseUtil } from '../utils/DatabaseUtil';

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
      this.filteredCiphers = [...this.allCiphers];
      
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
          await this.saveCipherToDatabase(cipher);
        }
        
        // 重新从数据库加载并显示
        const ciphersData = await DatabaseUtil.getInstance().queryAllData(DBTableName.MAIN);
        this.allCiphers = await this.buildCiphersFromData(ciphersData);
        this.filteredCiphers = [...this.allCiphers];
        
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
   * @param filterType 筛选类型：all, favorites, folders
   * @param searchText 搜索文本
   */
  filterCiphers(filterType: string, searchText: string): void {
    let filtered = [...this.allCiphers];

    // 按类型筛选
    switch (filterType) {
      case 'favorites':
        filtered = filtered.filter(cipher => cipher.favorite);
        break;
      case 'folders':
        filtered = filtered.filter(cipher => cipher.folderId !== null);
        break;
      case 'all':
      default:
        // 不筛选
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
   * 切换收藏状态
   * @param cipher 密码项
   * @param isFavorite 是否收藏
   */
  async toggleFavorite(cipher: Cipher, isFavorite: boolean): Promise<void> {
    cipher.favorite = isFavorite;
    updateCipher(cipher.id, cipher);
  }

  /**
   * 清除错误信息
   */
  clearError(): void {
    this.errorMessage = '';
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
        
        stats.total++;
        
        if (favorite === 1) {
          stats.favorite++;
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

  /**
   * 保存密码项到数据库
   * @param cipher 密码项对象
   */
  async saveCipherToDatabase(cipher: Cipher) {
    try {
      // 保存主表数据
      const cipherData: relationalStore.ValuesBucket = {
        id: cipher.id,
        type: cipher.type,
        name: cipher.name,
        favorite: cipher.favorite ? 1 : 0,
        edit: cipher.edit ? 1 : 0,
        folder_id: cipher.folderId || null,
        organization_id: cipher.organizationId || null,
        creation_date: cipher.creationDate,
        revision_date: cipher.revisionDate || null,
        deleted_date: cipher.deletedDate || null,
        notes: cipher.notes || null,
        reprompt: cipher.reprompt
      };
      await DatabaseUtil.getInstance().insertData(DBTableName.MAIN, cipherData);

      // 保存登录信息
      if (cipher.login && cipher.type == CipherItemType.LOGIN) {
        const loginData: relationalStore.ValuesBucket = {
          id: `${cipher.id}_login`,
          cipher_id: cipher.id,
          username: cipher.login.username || '',
          password: cipher.login.password || '',
          password_revision_date: cipher.login.passwordRevisionDate || null,
          totp: cipher.login.totp || null,
          uris: cipher.login.uris ? JSON.stringify(cipher.login.uris) : null
        };
        await DatabaseUtil.getInstance().insertData(DBTableName.LOGINS, loginData);
      }

      // 保存卡片信息
      if (cipher.card && cipher.type == CipherItemType.CARD) {
        const cardData: relationalStore.ValuesBucket = {
          id: `${cipher.id}_card`,
          cipher_id: cipher.id,
          cardholder_name: cipher.card.cardholderName || '',
          brand: cipher.card.brand || '',
          number: cipher.card.number || '',
          exp_month: cipher.card.expMonth || '',
          exp_year: cipher.card.expYear || '',
          code: cipher.card.code || ''
        };
        await DatabaseUtil.getInstance().insertData(DBTableName.CARDS, cardData);
      }

      // 保存身份信息
      if (cipher.identity && cipher.type == CipherItemType.IDENTITY) {
        const identityData: relationalStore.ValuesBucket = {
          id: `${cipher.id}_identity`,
          cipher_id: cipher.id,
          title: cipher.identity.title || null,
          first_name: cipher.identity.firstName || null,
          middle_name: cipher.identity.middleName || null,
          last_name: cipher.identity.lastName || null,
          address1: cipher.identity.address1 || null,
          address2: cipher.identity.address2 || null,
          address3: cipher.identity.address3 || null,
          city: cipher.identity.city || null,
          state: cipher.identity.state || null,
          postal_code: cipher.identity.postalCode || null,
          country: cipher.identity.country || null,
          company: cipher.identity.company || null,
          email: cipher.identity.email || null,
          phone: cipher.identity.phone || null,
          ssn: cipher.identity.ssn || null,
          username: cipher.identity.username || null,
          passport_number: cipher.identity.passportNumber || null,
          license_number: cipher.identity.licenseNumber || null
        };
        await DatabaseUtil.getInstance().insertData(DBTableName.IDENTITIES, identityData);
      }

      // 保存安全笔记
      if (cipher.secureNote && cipher.type == CipherItemType.NOTE) {
        const noteData: relationalStore.ValuesBucket = {
          id: `${cipher.id}_note`,
          cipher_id: cipher.id,
          type: cipher.secureNote.type || 0
        };
        await DatabaseUtil.getInstance().insertData(DBTableName.NOTES, noteData);
      }

      // 保存自定义字段
      if (cipher.fields && Array.isArray(cipher.fields)) {
        for (let i = 0; i < cipher.fields.length; i++) {
          const field = cipher.fields[i] as CipherField;
          const fieldData: relationalStore.ValuesBucket = {
            id: `${cipher.id}_field_${i}`,
            cipher_id: cipher.id,
            name: field.name || '',
            value: field.value || '',
            type: field.type || 0
          };
          await DatabaseUtil.getInstance().insertData(DBTableName.FIELDS, fieldData);
        }
      }
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to save cipher to database, error message: ${error.message}`);
    }
  }
}

interface CipherStats{
  total: number,
  login: number,
  note: number,
  card: number,
  identity: number,
  favorite: number,
  deleted: number
}