import { getAllCiphers, updateCipher } from '../network/CipherApi.ets';
import { Cipher, CipherLogin, CipherCard, CipherIdentity, CipherSecureNote, CipherField } from '../model/CipherModels.ets';
import { Logger } from '@nzy/logger';
import { CipherItemType, CipherFieldType, DBTableName } from '../utils/Constants';
import { queryAllData, deleteAllData, saveCipherToDatabase } from '../utils/DatabaseUtil';
import { ValuesBucket } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

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
      const ciphersData = await queryAllData(DBTableName.MAIN);
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
        
        // 删除数据库中所有密码项
        await deleteAllData(DBTableName.MAIN);
        
        // 将服务器数据保存到数据库
        for (const cipher of response.data) {
          saveCipherToDatabase(cipher);
        }
        
        // 重新从数据库加载并显示
        const ciphersData = await queryAllData(DBTableName.MAIN);
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
  private async buildCiphersFromData(ciphersData: ValuesBucket[]): Promise<Cipher[]> {
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
      if (cipher.type === CipherItemType.LOGIN) {
        cipher.login = await this.getCipherLogin(cipher.id!);
      } else if (cipher.type === CipherItemType.CARD) {
        cipher.card = await this.getCipherCard(cipher.id!);
      } else if (cipher.type === CipherItemType.IDENTITY) {
        cipher.identity = await this.getCipherIdentity(cipher.id!);
      } else if (cipher.type === CipherItemType.NOTE) {
        cipher.secureNote = await this.getCipherSecureNote(cipher.id!);
      }

      // 加载自定义字段
      cipher.fields = await this.getCipherFields(cipher.id!);

      ciphers.push(cipher);
    }
    
    return ciphers;
  }

  /**
   * 获取登录信息
   */
  private async getCipherLogin(cipherId: string): Promise<CipherLogin | null> {
    try {
      const loginData = await queryAllData(DBTableName.LOGINS);
      const loginRecord = loginData.find(data => data.cipher_id === cipherId);
      
      if (loginRecord) {
        return {
          username: loginRecord.username as string || '',
          password: loginRecord.password as string || '',
          passwordRevisionDate: loginRecord.password_revision_date as string || null,
          totp: loginRecord.totp as string || null,
          uris: loginRecord.uris ? JSON.parse(loginRecord.uris as string) : undefined
        };
      }
    } catch (error) {
      Logger.error(`Failed to get login info for cipher ${cipherId}: ${error}`);
    }
    return null;
  }

  /**
   * 获取卡片信息
   */
  private async getCipherCard(cipherId: string): Promise<CipherCard | null> {
    try {
      const cardData = await queryAllData(DBTableName.CARDS);
      const cardRecord = cardData.find(data => data.cipher_id === cipherId);
      
      if (cardRecord) {
        return {
          cardholderName: cardRecord.cardholder_name as string,
          brand: cardRecord.brand as string,
          number: cardRecord.number as string,
          expMonth: cardRecord.exp_month as string,
          expYear: cardRecord.exp_year as string,
          code: cardRecord.code as string
        };
      }
    } catch (error) {
      Logger.error(`Failed to get card info for cipher ${cipherId}: ${error}`);
    }
    return null;
  }

  /**
   * 获取身份信息
   */
  private async getCipherIdentity(cipherId: string): Promise<CipherIdentity | null> {
    try {
      const identityData = await queryAllData(DBTableName.IDENTITIES);
      const identityRecord = identityData.find(data => data.cipher_id === cipherId);
      
      if (identityRecord) {
        return {
          address1: identityRecord.address1 as string || null,
          address2: identityRecord.address2 as string || null,
          address3: identityRecord.address3 as string || null,
          city: identityRecord.city as string || null,
          company: identityRecord.company as string || null,
          country: identityRecord.country as string || null,
          email: identityRecord.email as string || null,
          firstName: identityRecord.first_name as string || null,
          lastName: identityRecord.last_name as string || null,
          licenseNumber: identityRecord.license_number as string || null,
          middleName: identityRecord.middle_name as string || null,
          passportNumber: identityRecord.passport_number as string || null,
          phone: identityRecord.phone as string || null,
          postalCode: identityRecord.postal_code as string || null,
          ssn: identityRecord.ssn as string || null,
          state: identityRecord.state as string || null,
          title: identityRecord.title as string || null,
          username: identityRecord.username as string || null
        };
      }
    } catch (error) {
      Logger.error(`Failed to get identity info for cipher ${cipherId}: ${error}`);
    }
    return null;
  }

  /**
   * 获取安全笔记
   */
  private async getCipherSecureNote(cipherId: string): Promise<CipherSecureNote | null> {
    try {
      const noteData = await queryAllData(DBTableName.NOTES);
      const noteRecord = noteData.find(data => data.cipher_id === cipherId);
      
      if (noteRecord) {
        return {
          type: noteRecord.type as CipherFieldType
        };
      }
    } catch (error) {
      Logger.error(`Failed to get secure note for cipher ${cipherId}: ${error}`);
    }
    return null;
  }

  /**
   * 获取自定义字段
   */
  private async getCipherFields(cipherId: string): Promise<CipherField[]> {
    try {
      const fieldsData = await queryAllData(DBTableName.FIELDS);
      const fields: CipherField[] = [];
      
      for (const fieldData of fieldsData) {
        if (fieldData.cipher_id === cipherId) {
          fields.push({
            name: fieldData.name as string,
            value: fieldData.value as string,
            type: fieldData.type as CipherFieldType
          });
        }
      }
      
      return fields;
    } catch (error) {
      Logger.error(`Failed to get fields for cipher ${cipherId}: ${error}`);
      return [];
    }
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
      const ciphersData = await queryAllData(DBTableName.MAIN);
      
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