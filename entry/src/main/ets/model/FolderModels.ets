/** 服务端和数据库中的文件夹；名称始终为账户密钥加密的密文。 */
export interface VaultFolder {
  id: string;
  name: string;
  revisionDate?: string;
}

/** 解锁会话中的文件夹名称，解密失败仍保留 ID，避免丢失归属。 */
export interface FolderView {
  id: string;
  name: string;
  unavailable: boolean;
}

/** 文件夹选择项使用稳定 ID，数量仅供密码库筛选展示。 */
export interface FolderOption {
  value: string;
  text: ResourceStr;
  count?: number;
  manageable?: boolean;
  editableName?: string;
}

// 空字符串表示无文件夹；该值仅用于界面，不发送给服务端。
export const ALL_FOLDERS: string = '__all_folders__';
