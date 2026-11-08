import { FolderOption, FolderView } from '../model/FolderModels';
import { DatabaseUtil } from './DatabaseUtil';
import { DBTableName } from './Constants';
import { CryptoUtil } from './CryptoUtil';
import { LocaleUtil } from '../localization/LocaleUtil';

/** 只在调用方会话内解密文件夹，不缓存明文名称或密钥。 */
export class FolderRepository {
  /** 离线读取密文缓存，单个名称损坏不阻断其他文件夹。 */
  static async load(symmetricKey: string): Promise<FolderView[]> {
    await DatabaseUtil.getInstance().createTable();
    const rows = await DatabaseUtil.getInstance().queryAllData(DBTableName.FOLDERS);
    const folders = await Promise.all(rows.map(async (row): Promise<FolderView> => {
      try {
        return { id: row.id as string, name: await CryptoUtil.decryptField(row.name as string, symmetricKey),
          unavailable: false };
      } catch (_) {
        return { id: row.id as string, name: '', unavailable: true };
      }
    }));
    return folders.sort((left: FolderView, right: FolderView) =>
      left.name.localeCompare(right.name, LocaleUtil.getLanguage()) || left.id.localeCompare(right.id));
  }

  /** 保留完整路径，父子文件夹分别按 ID 筛选。 */
  static options(folders: FolderView[]): FolderOption[] {
    return folders.map((folder: FolderView): FolderOption => ({ value: folder.id,
      text: folder.unavailable ? $r('app.string.folder_unavailable') : folder.name,
      manageable: !folder.unavailable, editableName: folder.unavailable ? undefined : folder.name }));
  }
}
