import { FolderOption } from '../model/FolderModels';
import { FolderRepository } from '../utils/FolderRepository';
import { FolderPicker } from './FolderPicker';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { AppErrorDialog } from '../utils/AppErrorDialog';

/** 各类型密码项共用的文件夹字段，异步选项不进入表单修改快照。 */
@Component
export struct CipherFolderField {
  @StorageLink('vaultFolderRevision') @Watch('handleFolderRevision') folderRevision: number = 0;
  @Prop folderId: string = '';
  @Prop symmetricKey: string = '';
  @Prop editable: boolean = false;
  @Prop disabled: boolean = false;
  // 新建页使用上下排布；详情编辑页与名称行共用标签宽度和输入区边距。
  @Prop stackedLabel: boolean = false;
  @State private options: FolderOption[] = [{ value: '', text: $r('app.string.folder_none') }];
  private mounted: boolean = false;
  private loadRevision: number = 0;
  onChange: (folderId: string | null) => void = () => {};
  onFolderDeleted: (folderId: string) => void = () => {};

  /** 页面关闭或会话变化后丢弃迟到的明文名称。 */
  async aboutToAppear(): Promise<void> {
    this.mounted = true;
    await this.loadFolders();
  }

  /** 只刷新目录选项，保留密码项草稿的其他字段。 */
  private handleFolderRevision(): void {
    const deleted = AppStorage.get<string>('vaultDeletedFolderId') || '';
    if (deleted) { this.onFolderDeleted(deleted); }
    void this.loadFolders();
  }

  /** 代次和会话检查阻止旧加载覆盖新目录。 */
  private async loadFolders(): Promise<void> {
    const revision = ++this.loadRevision;
    const session = VaultViewModel.getSessionRevision();
    try {
      const folders = await FolderRepository.load(this.symmetricKey);
      if (this.mounted && revision === this.loadRevision && session === VaultViewModel.getSessionRevision() && VaultViewModel.isSessionActive()) {
        this.options = [{ value: '', text: $r('app.string.folder_none') }, ...FolderRepository.options(folders)];
      }
    } catch (error) {
      if (this.mounted && revision === this.loadRevision && session === VaultViewModel.getSessionRevision()) {
        AppErrorDialog.showError(this.getUIContext(), error, $r('app.string.error_load_failed'));
      }
    }
  }

  /** 标记组件离开，禁止迟到的加载结果重新填充界面。 */
  aboutToDisappear(): void {
    this.mounted = false;
  }

  /** 两种表单布局共用同一文件夹控件和选择事件。 */
  @Builder
  private folderValue() {
    if (this.editable) {
      FolderPicker({ options: this.options, value: this.folderId, disabled: this.disabled, symmetricKey: this.symmetricKey,
        allowFolderManagement: false,
        onChange: (value: string) => this.onChange(value || null) })
    } else {
      Text(this.options.find((option: FolderOption) => option.value === this.folderId)?.text ??
        $r('app.string.folder_unavailable')).fontSize(14).width('100%')
    }
  }

  build() {
    if (this.stackedLabel) {
      Column({ space: 4 }) {
        Text($r('app.string.folder_title')).fontSize(14)
          .fontColor($r('app.color.cipher_label_foreground'))
        this.folderValue()
      }.alignItems(HorizontalAlign.Start).width('100%').padding({ top: 8, bottom: 8 })
    } else {
      Row() {
        Text($r('app.string.folder_title')).fontSize(14)
          .fontColor($r('app.color.cipher_label_foreground')).width(112)
        Column() {
          this.folderValue()
        }.layoutWeight(1).margin({ left: this.editable ? 16 : 0, right: this.editable ? 16 : 0 })
      }.width('100%').padding({ top: 8, bottom: 8 })
    }
  }
}
