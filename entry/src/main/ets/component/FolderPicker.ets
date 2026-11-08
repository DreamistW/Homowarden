import { FolderOption } from '../model/FolderModels';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { FormDialog } from './FormDialog';
import { FolderMutationService } from '../utils/FolderMutationService';
import { AppErrorDialog } from '../utils/AppErrorDialog';
import { VaultViewModel } from '../viewmodel/VaultViewModel';

/** 可搜索的文件夹选择器；直接回传 ID，选项重排不会改变归属。 */
@Component
export struct FolderPicker {
  @StorageLink('localeRevision') localeRevision: number = 0;
  @Prop options: FolderOption[] = [];
  @Prop value: string = '';
  @Prop disabled: boolean = false;
  @Prop symmetricKey: string = '';
  @Prop filterScope: boolean = false;
  // 密码项表单只创建和选择目录，重命名与删除集中在密码库入口。
  @Prop allowFolderManagement: boolean = true;
  @StorageLink('vaultFolderRevision') @Watch('handleFolderRevision') folderRevision: number = 0;
  @State private showPicker: boolean = false;
  @State private searchText: string = '';
  @State private actionName: string = '';
  @State private actionKind: string = '';
  @State private actionOpen: boolean = false;
  @State private actionBusy: boolean = false;
  private actionController: CustomDialogController | null = null;
  private actionGeneration: number = 0;
  private mounted: boolean = false;
  // 使用系统向右符号表示打开文件夹选择面板，其余外观沿用原生筛选入口。
  private folderArrow: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.chevron_right'));
  onChange: (value: string) => void = () => {};

  /** 控制器归属本实例，页面消失后不允许旧请求关闭其他弹窗。 */
  aboutToAppear(): void { this.mounted = true; }

  aboutToDisappear(): void {
    this.mounted = false;
    this.actionGeneration++;
    this.actionController?.close();
    this.actionController = null;
  }

  /** 删除当前筛选目录后展示无文件夹项目，表单归属由页面同步处理。 */
  private handleFolderRevision(): void {
    const deletedId = AppStorage.get<string>('vaultDeletedFolderId') || '';
    if (this.filterScope && deletedId && this.value === deletedId) {
      this.onChange('');
    }
  }

  /** 额外的操作弹窗只负责当前捕获目标，不收起文件夹列表。 */
  private openAction(kind: string, option?: FolderOption): void {
    if (this.actionOpen || this.disabled || !this.symmetricKey) { return; }
    if (kind !== 'create' && !this.allowFolderManagement) { return; }
    const targetId = option?.value || '';
    const session = VaultViewModel.getSessionRevision();
    const generation = ++this.actionGeneration;
    this.actionKind = kind;
    this.actionName = option?.editableName || '';
    this.actionOpen = true;
    const title: ResourceStr = kind === 'create' ? $r('app.string.folder_create') :
      kind === 'rename' ? $r('app.string.folder_rename') : $r('app.string.folder_delete');
    this.actionController = new CustomDialogController({
      builder: FormDialog({ title: title, contentBuilder: (): void => this.actionContent(),
        confirm: async (): Promise<void> => {
          if (this.actionBusy || !this.mounted || generation !== this.actionGeneration ||
            session !== VaultViewModel.getSessionRevision() || !VaultViewModel.isSessionActive()) { return; }
          const name = this.actionName.trim();
          if (kind !== 'delete' && !name) {
            AppErrorDialog.show(this.getUIContext(), $r('app.string.folder_name_required'));
            return;
          }
          this.actionBusy = true;
          try {
            if (kind === 'delete') {
              await FolderMutationService.remove(targetId);
            } else {
              await FolderMutationService.save(targetId, name, this.symmetricKey);
            }
            if (this.mounted && generation === this.actionGeneration && session === VaultViewModel.getSessionRevision()) {
              this.actionController?.close();
            }
          } finally {
            if (this.mounted && generation === this.actionGeneration) { this.actionBusy = false; }
          }
        }
      }),
      autoCancel: false, customStyle: false, alignment: DialogAlignment.Center,
      onWillDismiss: (action: DismissDialogAction): void => {
        if (!this.actionBusy) { action.dismiss(); }
      },
      onDidDisappear: (): void => {
        if (this.mounted && generation === this.actionGeneration) {
          this.actionOpen = false;
          this.actionController = null;
        }
      }
    });
    this.actionController.open();
  }

  /** 名称输入与删除确认共用现有表单对话框，错误内联展示。 */
  @Builder
  private actionContent() {
    if (this.actionKind === 'delete') {
      Text($r('app.string.folder_delete_confirm', this.actionName)).fontSize(16)
    } else {
      TextInput({ text: this.actionName, placeholder: $r('app.string.folder_name') })
        .id('folder_action_name')
        .accessibilityText($r('app.string.folder_name'))
        .onChange((value: string) => { this.actionName = value; })
    }
  }

  /** 独立图标按钮不嵌套在选中按钮内，管理点击不会触发目录选择。 */
  @Builder
  private actionButton(icon: Resource, label: Resource, action: () => void, id: string) {
    Button({ type: ButtonType.Normal }) {
      Image(icon).width(20).height(20).fillColor($r('sys.color.ohos_id_color_text_primary'))
    }.id(id).width(40).height(40).padding(10).borderRadius(8)
      .backgroundColor(Color.Transparent).accessibilityText(label)
      .enabled(!this.disabled && !this.actionOpen).onClick(action)
  }

  /** 缺失文件夹显示不可用，不回退成“无文件夹”。 */
  private selectedText(_revision: number): ResourceStr {
    return this.options.find((option: FolderOption) => option.value === this.value)?.text ??
      $r('app.string.folder_unavailable');
  }

  /** 资源名称按当前语言参与搜索，用户文件夹名保持原文。 */
  private visibleOptions(_revision: number): FolderOption[] {
    const query = this.searchText.trim().toLocaleLowerCase();
    return this.options.filter((option: FolderOption) => {
      const text = typeof option.text === 'string' ? option.text :
        this.getUIContext().getHostContext()?.resourceManager.getStringSync(option.text.id) ?? '';
      return text.toLocaleLowerCase().includes(query);
    });
  }

  /** 选项对象是不可变快照，名称或数量变化时重建该行，避免 ForEach 按 ID 复用旧文案。 */
  private optionRowKey(option: FolderOption): string {
    const text = typeof option.text === 'string' ? option.text : `${option.text.id}`;
    return `${option.value}:${text}:${option.count ?? ''}:${option.manageable ?? false}`;
  }

  /** 名称和数量均可选择目录，管理操作打开期间不改变选择。 */
  private selectFolder(value: string): void {
    if (this.disabled || this.actionOpen) { return; }
    this.showPicker = false;
    this.onChange(value);
  }

  /** 选择即提交给表单草稿，持久化仍由页面的保存动作负责。 */
  @Builder
  private pickerContent() {
    Column({ space: 12 }) {
      Row() {
        this.actionButton($r('app.media.icon_add'), $r('app.string.folder_create'),
          () => this.openAction('create'), 'folder_create_button')
        Text($r('app.string.folder_title')).fontSize(20).fontWeight(FontWeight.Medium).layoutWeight(1)
          .textAlign(TextAlign.Center)
        this.actionButton($r('app.media.icon_cancel'), $r('app.string.folder_close'),
          () => { this.showPicker = false; }, 'folder_close_button')
      }.width('100%')
      Search({ value: this.searchText, placeholder: $r('app.string.folder_search') })
        .id('folder_picker_search')
        .onChange((value: string) => { this.searchText = value; })
      List({ space: 8 }) {
        ForEach(this.visibleOptions(this.localeRevision), (option: FolderOption) => {
          ListItem() {
            Row() {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 8 }) {
                  Text(option.text).fontSize(16).layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width('100%').padding(12).constraintSize({ minHeight: 48 })
              }
              .id(`folder_option_${option.value || 'none'}`)
              .layoutWeight(1)
              .borderRadius(8)
              .backgroundColor(Color.Transparent)
              .fontColor(option.value === this.value ? $r('app.color.brand_accent_color') :
                $r('sys.color.ohos_id_color_text_primary'))
              .enabled(!this.disabled && !this.actionOpen)
              .onClick(() => this.selectFolder(option.value))
              if (option.manageable && this.allowFolderManagement) {
                this.actionButton($r('app.media.icon_edit'), $r('app.string.folder_rename'),
                  () => this.openAction('rename', option), `folder_rename_${option.value}`)
                this.actionButton($r('app.media.icon_delete'), $r('app.string.folder_delete'),
                  () => this.openAction('delete', option), `folder_delete_${option.value}`)
              } else if (this.allowFolderManagement) {
                Blank().width(80)
              }
              if (option.count !== undefined) {
                // 数量独占最右列；两个管理按钮位于数量左侧。
                Text(`${option.count}`).fontSize(14).constraintSize({ minWidth: 48 })
                  .textAlign(TextAlign.End).padding({ left: 8, right: 12 })
                  .fontColor(option.value === this.value ? $r('app.color.brand_accent_color') :
                    $r('sys.color.ohos_id_color_text_primary'))
                  .id(`folder_count_${option.value || 'none'}`)
                  .enabled(!this.disabled && !this.actionOpen)
                  .onClick(() => this.selectFolder(option.value))
              }
            }.width('100%').borderRadius(8)
              .backgroundColor(option.value === this.value ? $r('app.color.secondary_button_background_color') : Color.Transparent)
          }
        }, (option: FolderOption): string => this.optionRowKey(option))
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').padding(24)
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      // 复用 AppDropdown 的原生 Select 外观；事件和焦点交给外层按钮打开搜索弹窗。
      Select([{ value: this.selectedText(this.localeRevision) }])
        .selected(0)
        .value(this.selectedText(this.localeRevision))
        .font({ size: 14, weight: FontWeight.Regular })
        .arrowModifier(this.folderArrow)
        .width('100%').height(40)
        .enabled(!this.disabled)
        .hitTestBehavior(HitTestMode.None)
        .focusable(false)
        .accessibilityLevel('no-hide-descendants')
    }
    .id('folder_picker_button')
    .height(40).width('100%').padding(0)
    .backgroundColor(Color.Transparent)
    .hoverEffect(HoverEffect.None)
    .accessibilityText($r('app.string.folder_title'))
    .enabled(!this.disabled)
    .onClick(() => { this.searchText = ''; this.showPicker = true; })
    .bindSheet($$this.showPicker, this.pickerContent,
      // 跟手弹窗默认允许外部交互；统一使用遮罩承接外部点击并关闭，避免误操作底层项目。
      // 创建和关闭使用同一行同尺寸按钮，隐藏系统关闭按钮避免两套标题栏坐标不一致。
      { detents: [SheetSize.LARGE], showClose: false, enableOutsideInteractive: false,
        onWillDismiss: (action: DismissSheetAction): void => {
          if (!this.actionOpen) { action.dismiss(); }
        }
      })
  }
}
