import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';
import { hdsMaterial, HdsNavDestination, HdsNavigationBadgeIconOptions } from '@kit.UIDesignKit';
import { GeneratorDatabaseUtil, GENERATOR_HISTORY_TABLE } from '../utils/GeneratorDatabaseUtil';
import { GeneratorHistoryItem, GeneratorRecordType } from '../model/GeneratorHistoryModel';
import { AdaptiveIconButton } from '../component/AdaptiveButton';
import { AppToast } from '../utils/AppToast';
import { DetailRouter } from '../utils/DetailRouter';
import { ConfirmDialog } from '../component/ConfirmDialog';

@Builder
export function GeneratorHistoryPageBuilder() {
  GeneratorHistory();
}

@Component
struct GeneratorHistory {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  @StorageLink('activeSplitView') isSplitView: boolean = false;
  pathInfos: NavPathStack = new NavPathStack();
  @State historyList: GeneratorHistoryItem[] = [];
  @State inSelectionMode: boolean = false;
  @State selectedIds: string[] = [];
  private dbUtil: GeneratorDatabaseUtil = GeneratorDatabaseUtil.getInstance();
  private refreshTimer: number = -1;
  private isPageActive: boolean = false;
  private appearanceGeneration: number = 0;

  clearBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.generator_history_clear'),
      icon: $r('app.media.icon_delete'),
      action: () => {
        this.requestClearAll();
      }
    }
  };

  async aboutToAppear(): Promise<void> {
    this.isPageActive = true;
    this.appearanceGeneration++;
    const currentGeneration: number = this.appearanceGeneration;
    await this.loadHistory();
    if (!this.isPageActive || currentGeneration !== this.appearanceGeneration) {
      return;
    }
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
    }
    this.refreshTimer = setInterval(() => {
      this.historyList = [...this.historyList];
    }, 60000);
  }

  aboutToDisappear(): void {
    this.isPageActive = false;
    this.appearanceGeneration++;
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
    // 旋转跨栈迁移会销毁本页，随之关闭未决确认框（等同取消）。
    this.confirmController.close();
  }

  @State confirmTitle: ResourceStr = '';
  @State confirmMessage: ResourceStr = '';
  @State confirmText: ResourceStr = $r('app.string.common_confirm');
  private confirmAction: () => Promise<boolean> = async () => true;
  private confirmController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: $confirmTitle,
      message: $confirmMessage,
      confirmText: $confirmText,
      onConfirm: async (): Promise<boolean> => {
        return await this.confirmAction();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  private showConfirm(title: ResourceStr, message: ResourceStr, action: () => void,
    confirmText: ResourceStr = $r('app.string.common_confirm')): void {
    this.confirmTitle = title;
    this.confirmMessage = message;
    this.confirmText = confirmText;
    this.confirmAction = async (): Promise<boolean> => {
      action();
      return true;
    };
    this.confirmController.open();
  }

  private handleLocaleRevision(): void {
    this.historyList = [...this.historyList];
  }

  // 从数据库加载历史记录（按时间倒序）
  async loadHistory(): Promise<void> {
    try {
      const results = await this.dbUtil.queryAllHistory();
      const items: GeneratorHistoryItem[] = [];
      for (let i = 0; i < results.length; i++) {
        const row = results[i];
        const item: GeneratorHistoryItem = {
          id: row.id as string,
          content: row.content as string,
          type: row.type as GeneratorRecordType,
          timestamp: row.timestamp as number
        };
        items.push(item);
      }
      this.historyList = items;
    } catch (err) {
      Logger.error(`Failed to load generator history: ${JSON.stringify(err)}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_load_failed'));
    }
  }

  // 复制功能
  private async copyContent(text: string): Promise<void> {
    if (text.length === 0) {
      return;
    }
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      AppToast.show(this.getUIContext(), $r('app.string.generator_copied'));
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to copy generator content: ${err.message}`);
    }
  }

  // 弹出确认对话框请求删除单条记录。
  private requestDelete(item: GeneratorHistoryItem): void {
    this.showConfirm($r('app.string.generator_history_delete_confirm'), item.content, () => {
      void this.doDelete(item);
    });
  }

  // 弹出确认对话框请求清空全部记录。
  private requestClearAll(): void {
    this.showConfirm($r('app.string.common_confirm'), $r('app.string.generator_history_clear_confirm'), () => {
      void this.doClearAll();
    });
  }

  // 删除指定记录并刷新列表。
  private async doDelete(item: GeneratorHistoryItem): Promise<void> {
    try {
      await this.dbUtil.deleteData(GENERATOR_HISTORY_TABLE, item.id);
      await this.loadHistory();
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to delete generator history: code=${error.code}, message=${error.message}`);
      AppToast.show(this.getUIContext(), error.message.length > 0 ?
        error.message : $r('app.string.error_delete_failed'));
    }
  }

  // 清空全部记录并刷新列表。
  private async doClearAll(): Promise<void> {
    try {
      await this.dbUtil.deleteAllData(GENERATOR_HISTORY_TABLE);
      await this.loadHistory();
      AppToast.show(this.getUIContext(), $r('app.string.generator_cleared'));
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to clear generator history: code=${error.code}, message=${error.message}`);
      AppToast.show(this.getUIContext(), error.message.length > 0 ?
        error.message : $r('app.string.error_delete_failed'));
    }
  }

  // 长按进入多选模式并预选当前项目。
  private enterSelectionMode(item: GeneratorHistoryItem): void {
    this.inSelectionMode = true;
    this.selectedIds = [item.id];
  }

  // 切换某条记录的选中状态。
  private toggleSelection(id: string): void {
    if (this.selectedIds.includes(id)) {
      this.selectedIds = this.selectedIds.filter(i => i !== id);
    } else {
      this.selectedIds = [...this.selectedIds, id];
    }
  }

  // 判断当前列表是否已全部选中。
  private isAllSelected(): boolean {
    return this.historyList.length > 0 &&
      this.historyList.every((item: GeneratorHistoryItem) => this.selectedIds.includes(item.id));
  }

  // 全选或取消全选当前列表。
  private toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.selectedIds = [];
    } else {
      this.selectedIds = this.historyList.map((item: GeneratorHistoryItem) => item.id);
    }
  }

  // 判断某条记录是否处于选中状态。
  private isSelected(id: string): boolean {
    return this.selectedIds.includes(id);
  }

  // 退出多选模式并清空选择。
  private exitSelectionMode(): void {
    this.inSelectionMode = false;
    this.selectedIds = [];
  }

  // 已选记录数量文案。
  private getSelectedCountText(): string {
    return this.getUIContext().getHostContext()?.resourceManager
      .getStringSync($r('app.string.history_selected_count').id, this.selectedIds.length) ?? '';
  }

  // 弹出确认对话框请求删除选中的记录。
  private requestDeleteSelected(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    this.showConfirm($r('app.string.common_delete'), $r('app.string.history_delete_selected_confirm'), () => {
      void this.doDeleteSelected();
    }, $r('app.string.common_delete'));
  }

  // 删除选中的记录并刷新列表。
  private async doDeleteSelected(): Promise<void> {
    const ids: string[] = [...this.selectedIds];
    try {
      for (const id of ids) {
        await this.dbUtil.deleteData(GENERATOR_HISTORY_TABLE, id);
      }
      this.exitSelectionMode();
      await this.loadHistory();
      AppToast.show(this.getUIContext(), $r('app.string.common_delete_success'));
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to delete selected generator history: code=${error.code}, message=${error.message}`);
      AppToast.show(this.getUIContext(), error.message.length > 0 ?
        error.message : $r('app.string.error_delete_failed'));
    }
  }

  // 相对时间格式化
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) {
      return this.getUIContext().getHostContext()?.resourceManager
        .getStringSync($r('app.string.share_just_now').id) ?? '';
    } else if (minutes < 60) {
      const resource: Resource = minutes === 1 ? $r('app.string.share_minute_ago') :
        $r('app.string.share_minutes_ago');
      return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id, minutes) ?? '';
    } else if (hours < 24) {
      const resource: Resource = hours === 1 ? $r('app.string.share_hour_ago') :
        $r('app.string.share_hours_ago');
      return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id, hours) ?? '';
    } else if (days < 7) {
      const resource: Resource = days === 1 ? $r('app.string.share_day_ago') :
        $r('app.string.share_days_ago');
      return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id, days) ?? '';
    } else {
      return date.toLocaleDateString();
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.historyList.length > 0) {
          // 历史记录列表
          List({ space: 8 }) {
            ForEach(this.historyList, (item: GeneratorHistoryItem) => {
              ListItem() {
                this.HistoryItemBuilder(item);
              }
            }, (item: GeneratorHistoryItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12 })
        } else {
          // 空状态占位
          Column() {
            Text($r('app.string.generator_history_empty'))
              .fontSize(16)
              .fontColor('#999999')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }

        // 多选模式下的底部操作栏
        if (this.inSelectionMode) {
          this.SelectionBarBuilder()
        }

      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: {
          mainTitle: $r('app.string.generator_history_title')
        },
        menu: { value: this.inSelectionMode ? [] : [this.clearBtn] }
      },
      enableComponentSafeArea: true,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .hideBackButton(this.isSplitView)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onBackPressed((): boolean => {
      if (this.inSelectionMode) {
        this.exitSelectionMode();
        return true;
      }
      if (this.isSplitView) {
        DetailRouter.closeDetail();
        return true;
      }
      return false;
    })
  }

  // 多选模式下的勾选指示器。直接在构建器内部读取选中状态以建立响应式依赖。
  @Builder
  SelectionIndicator(item: GeneratorHistoryItem) {
    Stack() {
      if (this.isSelected(item.id)) {
        Text('✓')
          .fontSize(14)
          .fontColor($r('app.color.button_foreground_color'))
      }
    }
    .width(22)
    .height(22)
    .borderRadius(11)
    .backgroundColor(this.isSelected(item.id) ? $r('app.color.button_background_color') : Color.Transparent)
    .border({ width: this.isSelected(item.id) ? 0 : 1.5, color: '#CCCCCC' })
    .margin({ right: 12 })
  }

  // 多选模式下的底部操作栏。
  @Builder
  SelectionBarBuilder() {
    Row({ space: 12 }) {
      Button($r('app.string.common_cancel'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.button_background_color'))
        .fontSize(16)
        .height(40)
        .onClick(() => {
          this.exitSelectionMode();
        })

      Button(this.isAllSelected() ? $r('app.string.common_deselect_all') : $r('app.string.common_select_all'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.button_background_color'))
        .fontSize(16)
        .height(40)
        .onClick(() => {
          this.toggleSelectAll();
        })

      Blank()

      Text(this.getSelectedCountText())
        .fontColor('#666666')
        .fontSize(14)

      Button() {
        Image($r('app.media.icon_delete'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.button_foreground_color'))
          .accessibilityLevel('no')
      }
        .type(ButtonType.Circle)
        .width(40)
        .height(40)
        .padding(0)
        .backgroundColor($r('app.color.button_background_color'))
        .enabled(this.selectedIds.length > 0)
        .opacity(this.selectedIds.length > 0 ? 1 : 0.4)
        .accessibilityText($r('app.string.common_delete'))
        .onClick(() => {
          this.requestDeleteSelected();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.start_window_background'))
  }

  // 单条历史记录卡片
  @Builder
  HistoryItemBuilder(item: GeneratorHistoryItem) {
    Row() {
      if (this.inSelectionMode) {
        this.SelectionIndicator(item)
      }

      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text(item.type === GeneratorRecordType.PASSWORD ?
            $r('app.string.generator_history_type_password') :
            $r('app.string.generator_history_type_username'))
            .fontSize(11)
            .fontColor('#666666')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .backgroundColor('#F0F0F0')
          Text(this.formatTime(item.timestamp))
            .fontSize(12)
            .fontColor('#999999')
        }

        Text(item.content)
          .fontSize(16)
          .fontFamily('monospace')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .align(Alignment.Start)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (!this.inSelectionMode) {
        Row({ space: 4 }) {
          AdaptiveIconButton({
            icon: $r('app.media.icon_copy'),
            accessibilityLabel: $r('app.string.accessibility_copy_generated'),
            barWidth: 36,
            barHeight: 36,
            iconWidth: 18,
            iconHeight: 18,
            contentPadding: 4,
            barBottomMargin: 0,
            onButtonClick: () => {
              this.copyContent(item.content);
            }
          })
          AdaptiveIconButton({
            icon: $r('app.media.icon_delete'),
            accessibilityLabel: $r('app.string.common_delete'),
            barWidth: 36,
            barHeight: 36,
            iconWidth: 18,
            iconHeight: 18,
            contentPadding: 4,
            barBottomMargin: 0,
            onButtonClick: () => {
              this.requestDelete(item);
            }
          })
        }
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor(this.inSelectionMode && this.isSelected(item.id) ?
      '#1A2B77D9' : $r('app.color.start_window_background'))
    .accessibilityGroup(this.inSelectionMode)
    .accessibilitySelected(this.isSelected(item.id))
    .onClick(() => {
      if (this.inSelectionMode) {
        this.toggleSelection(item.id);
      }
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          if (!this.inSelectionMode) {
            this.enterSelectionMode(item);
          }
        })
    )
  }

}
