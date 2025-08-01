import { getAllCiphers, updateCipher } from '../network/CipherApi.ets';
import { Cipher } from '../model/CipherModels.ets';
import { Logger } from '@nzy/logger';
import { CipherItemType } from '../utils/Constants';

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

  /**
   * 加载所有密码项
   */
  async loadCiphers(): Promise<void> {
    try {
      this.isLoading = true;
      this.errorMessage = '';
      
      const response = await getAllCiphers();
      this.allCiphers = response.data || [];
      this.filteredCiphers = [...this.allCiphers];
      
      Logger.debug(`Loaded ${this.allCiphers.length} ciphers`);
    } catch (error) {
      Logger.error(`Failed to load ciphers: ${error}`);
      this.errorMessage = '加载密码项失败';
    } finally {
      this.isLoading = false;
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
    // try {
    //   const updatedCipher = { cipher, favorite: isFavorite };
    //   await updateCipher(cipher.id!, updatedCipher);
    //
    //   // 更新本地数据
    //   const index = this.allCiphers.findIndex(c => c.id === cipher.id);
    //   if (index !== -1) {
    //     this.allCiphers[index] = updatedCipher;
    //   }
    //
    //   // 重新筛选
    //   this.filterCiphers('all', '');
    //
    //   Logger.debug(`Toggled favorite for cipher ${cipher.id}: ${isFavorite}`);
    // } catch (error) {
    //   Logger.error(`Failed to toggle favorite: ${error}`);
    //   this.errorMessage = '更新收藏状态失败';
    // }
  }

  /**
   * 获取密码项类型名称
   * @param type 类型ID
   */
  getCipherTypeName(type: number): string {
    switch (type) {
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

  /**
   * 获取密码项类型图标
   * @param type 类型ID
   */
  getCipherTypeIcon(type: number): string {
    switch (type) {
      case CipherItemType.LOGIN:
        return 'ic_login';
      case CipherItemType.NOTE:
        return 'ic_note';
      case CipherItemType.CARD:
        return 'ic_card';
      case CipherItemType.IDENTITY:
        return 'ic_identity';
      default:
        return 'ic_unknown';
    }
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
} 