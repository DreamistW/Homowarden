import { saveFolder, deleteFolder } from '../network/FolderApi';
import { CryptoUtil } from './CryptoUtil';
import { DatabaseUtil } from './DatabaseUtil';
import { DBTableName } from './Constants';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { VaultChangeNotifier } from './VaultChangeNotifier';

/** 协调服务端文件夹写入、密文缓存及列表通知，不持有界面草稿。 */
export class FolderMutationService {
  /** 锁定或换号后停止本地回填，避免旧请求写入新会话。 */
  private static requireSession(session: number): void {
    if (!VaultViewModel.isSessionActive() || session !== VaultViewModel.getSessionRevision()) {
      throw new Error('auth_session_expired');
    }
  }

  /** 创建或重命名；缺失服务端字段回退到已经发送的密文名称。 */
  static async save(id: string, name: string, symmetricKey: string): Promise<void> {
    const session = VaultViewModel.getSessionRevision();
    await VaultViewModel.runFolderMutation(async (): Promise<void> => {
      FolderMutationService.requireSession(session);
      const encryptedName = await CryptoUtil.encryptField(name.trim(), symmetricKey);
      FolderMutationService.requireSession(session);
      const folder = await saveFolder(id, encryptedName);
      FolderMutationService.requireSession(session);
      const folderId = folder.id || id;
      if (!folderId) { throw new Error('Invalid folder response'); }
      const database = DatabaseUtil.getInstance();
      await database.createTable();
      // 同一事务保证缓存更新失败时保留原目录。
      await database.beginTransaction();
      try {
        FolderMutationService.requireSession(session);
        await database.deleteData(DBTableName.FOLDERS, folderId);
        await database.insertData(DBTableName.FOLDERS, { id: folderId,
          name: folder.name || encryptedName, revision_date: folder.revisionDate || null });
        FolderMutationService.requireSession(session);
        await database.commitTransaction();
      } catch (error) {
        await database.rollBackTransaction();
        throw error as Error;
      }
    });
    FolderMutationService.requireSession(session);
    VaultChangeNotifier.notifyFolderChanged();
  }

  /** 删除目录时只解除密码项的 folder_id，包含回收站内的项目。 */
  static async remove(id: string): Promise<void> {
    const session = VaultViewModel.getSessionRevision();
    await VaultViewModel.runFolderMutation(async (): Promise<void> => {
      FolderMutationService.requireSession(session);
      await deleteFolder(id);
      FolderMutationService.requireSession(session);
      const database = DatabaseUtil.getInstance();
      await database.beginTransaction();
      try {
        FolderMutationService.requireSession(session);
        await database.executeSql(`UPDATE ciphers SET folder_id = NULL WHERE folder_id = '${id.replace(/'/g, "''")}'`);
        await database.deleteData(DBTableName.FOLDERS, id);
        FolderMutationService.requireSession(session);
        await database.commitTransaction();
      } catch (error) {
        await database.rollBackTransaction();
        throw error as Error;
      }
    });
    FolderMutationService.requireSession(session);
    VaultChangeNotifier.notifyFolderChanged(id);
  }
}
