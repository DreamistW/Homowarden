import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { HistoryItem } from '../model/ShareHistoryModel';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { getShareLink } from '../utils/ParseLinkUtil';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { AdaptiveIconButton } from '../component/AdaptiveButton';
import { DetailRouter } from '../utils/DetailRouter';

@Builder
export function HistoryPageBuilder() {
  History();
}

@Component
struct History {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  @StorageLink('isSplitView') isSplitView: boolean = false;
  pathInfos: NavPathStack = new NavPathStack();
  @State searchText: string = '';
  @State historyList: HistoryItem[] = [];
  @State filteredList: HistoryItem[] = [];
  @State inSelectionMode: boolean = false;
  @State selectedIds: string[] = [];
  private dbUtil: ShareDatabaseUtil = ShareDatabaseUtil.getInstance();
  private refreshTimer: number = -1;
  private isPageActive: boolean = false;
  private appearanceGeneration: number = 0;

  async aboutToAppear() {
    this.isPageActive = true;
    this.appearanceGeneration++;
    const currentGeneration: number = this.appearanceGeneration;
    await this.loadHistory();
    // 异步查询返回时页面可能已离开或再次进入，旧生命周期不得启动计时器。
    if (!this.isPageActive || currentGeneration !== this.appearanceGeneration) {
      return;
    }
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
    }
    this.refreshTimer = setInterval(() => {
      // 相对时间依赖当前时刻，通过替换数组引用触发列表每分钟重绘。
      this.filteredList = [...this.filteredList];
    }, 60000);
  }

  aboutToDisappear(): void {
    // 递增代次同时使尚未结束的 aboutToAppear 异步流程失效。
    this.isPageActive = false;
    this.appearanceGeneration++;
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private handleLocaleRevision(): void {
    this.filteredList = [...this.filteredList];
  }

  // 从数据库加载历史记录
  async loadHistory() {
    try {
      const results = await this.dbUtil.queryHistoryBySearch(this.searchText);
      const historyItems: HistoryItem[] = [];
      for (let i = 0; i < results.length; i++) {
        const row = results[i];
        const item: HistoryItem = {
          id: row.id as string,
          content: row.content as string,
          timestamp: row.timestamp as number
        };
        historyItems.push(item);
      }
      this.historyList = historyItems;
      this.filteredList = this.historyList;
    } catch (err) {
      console.error(`Failed to load history. Error: ${JSON.stringify(err)}`);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.error_load_failed')
      });
    }
  }

  // 格式化时间
  formatTime(timestamp: number): string {
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

  // 搜索过滤
  async onSearchChange(value: string) {
    this.searchText = value;
    await this.loadHistory(); // 从数据库重新加载搜索结果
  }

  // 复制功能
  copyLink(text: string) {
    if (text == "") {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.share_convert_first')
      });
      return;
    }
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).catch((err: BusinessError) => {
      console.error(`Failed to set paste data. Code is ${err.code}, message is ${err.message}.`);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.share_copy_failed')
      });
      return;
    });
    this.getUIContext().getPromptAction().showToast({
      message: $r('app.string.share_copy_success')
    });
  }

  // 弹出确认对话框请求删除单条记录。
  requestDelete(item: HistoryItem): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.share_history_delete_confirm'),
      message: item.content,
      secondaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {}
      },
      primaryButton: {
        value: $r('app.string.common_confirm'),
        action: () => {
          void this.doDelete(item);
        }
      }
    });
  }

  // 删除指定记录并刷新列表。
  async doDelete(item: HistoryItem) {
    try {
      await this.dbUtil.deleteData('history', item.id);
      await this.loadHistory();
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.common_delete_success')
      });
    } catch (err) {
      console.error(`Failed to delete item. Error: ${JSON.stringify(err)}`);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.error_delete_failed')
      });
    }
  }

  // 长按进入多选模式并预选当前项目。
  enterSelectionMode(item: HistoryItem): void {
    this.inSelectionMode = true;
    this.selectedIds = [item.id];
  }

  // 切换某条记录的选中状态。
  toggleSelection(id: string): void {
    if (this.selectedIds.includes(id)) {
      this.selectedIds = this.selectedIds.filter(i => i !== id);
    } else {
      this.selectedIds = [...this.selectedIds, id];
    }
  }

  // 判断当前列表是否已全部选中。
  isAllSelected(): boolean {
    return this.filteredList.length > 0 &&
      this.filteredList.every((item: HistoryItem) => this.selectedIds.includes(item.id));
  }

  // 全选或取消全选当前列表。
  toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.selectedIds = [];
    } else {
      this.selectedIds = this.filteredList.map((item: HistoryItem) => item.id);
    }
  }

  // 判断某条记录是否处于选中状态。
  isSelected(id: string): boolean {
    return this.selectedIds.includes(id);
  }

  // 退出多选模式并清空选择。
  exitSelectionMode(): void {
    this.inSelectionMode = false;
    this.selectedIds = [];
  }

  // 已选记录数量文案。
  private getSelectedCountText(): string {
    return this.getUIContext().getHostContext()?.resourceManager
      .getStringSync($r('app.string.history_selected_count').id, this.selectedIds.length) ?? '';
  }

  // 弹出确认对话框请求删除选中的记录。
  requestDeleteSelected(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.common_delete'),
      message: $r('app.string.history_delete_selected_confirm'),
      secondaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {}
      },
      primaryButton: {
        value: $r('app.string.common_delete'),
        action: () => {
          void this.doDeleteSelected();
        }
      }
    });
  }

  // 删除选中的记录并刷新列表。
  async doDeleteSelected(): Promise<void> {
    const ids: string[] = [...this.selectedIds];
    try {
      for (const id of ids) {
        await this.dbUtil.deleteData('history', id);
      }
      this.exitSelectionMode();
      await this.loadHistory();
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.common_delete_success')
      });
    } catch (err) {
      console.error(`Failed to delete selected items. Error: ${JSON.stringify(err)}`);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.error_delete_failed')
      });
    }
  }

  shareLink(text: string, shareLink: boolean) {
    if (text == "") {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.share_convert_first')
      });
      return;
    }
    let shareData: systemShare.SharedData = new systemShare.SharedData({
      utd: shareLink ? uniformTypeDescriptor.UniformDataType.HYPERLINK : uniformTypeDescriptor.UniformDataType.TEXT,
      content: text
    });
    let controller: systemShare.ShareController = new systemShare.ShareController(shareData);
    let uiContext: UIContext = this.getUIContext();
    let context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
    controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DETAIL
    }).catch((err: BusinessError) => {
      console.error(`Failed to show share panel. Code is ${err.code}, message is ${err.message}.`);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.share_failed')
      });
    })
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 搜索栏
        Search({
          value: this.searchText,
          placeholder: $r('app.string.share_history_search')
        })
          .searchButton($r('app.string.common_search'))
          .onChange((value: string) => {
            this.onSearchChange(value);
          })
          .margin({
            top: 12,
            left: 16,
            right: 16,
            bottom: 12
          })

        // 历史记录列表
        if (this.filteredList.length > 0) {
          List({ space: 8 }) {
            ForEach(this.filteredList, (item: HistoryItem) => {
              ListItem() {
                this.HistoryItemBuilder(item);
              }
            }, (item: HistoryItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12 })
        } else {
          Column() {
            Text($r('app.string.share_history_empty'))
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
          mainTitle: $r('app.string.share_history_title')
        }
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
        DetailRouter.closeDetail(this.pathInfos);
        return true;
      }
      return false;
    })
  }

  // 多选模式下的勾选指示器。直接在构建器内部读取选中状态以建立响应式依赖。
  @Builder
  SelectionIndicator(item: HistoryItem) {
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
      }
        .type(ButtonType.Circle)
        .width(40)
        .height(40)
        .padding(0)
        .backgroundColor($r('app.color.button_background_color'))
        .enabled(this.selectedIds.length > 0)
        .opacity(this.selectedIds.length > 0 ? 1 : 0.4)
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
  HistoryItemBuilder(item: HistoryItem) {
    Row() {
      if (this.inSelectionMode) {
        this.SelectionIndicator(item)
      }

      Column({ space: 6 }) {
        Text(this.formatTime(item.timestamp))
          .fontSize(12)
          .fontColor('#999999')

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
        Row({ space: 12 }) {
          Button() {
            Image($r('app.media.icon_copy'))
              .width(18)
              .height(18)
              .fillColor($r('app.color.button_foreground_color'))
              .accessibilityLevel('no')
          }
            .type(ButtonType.Circle)
            .width(36)
            .height(36)
            .padding(0)
            .backgroundColor($r('app.color.button_background_color'))
            .accessibilityText($r('app.string.common_copy'))
            .bindMenu([
              {
                value: $r('app.string.share_copy_full'),
                action: () => {
                  this.copyLink(item.content);
                }
              },
              {
                value: $r('app.string.share_copy_link'),
                action: async () => {
                  const link: string = await getShareLink(item.content);
                  this.copyLink(link);
                }
              }
            ])

          Button() {
            Image($r('app.media.icon_share'))
              .width(18)
              .height(18)
              .fillColor($r('app.color.button_foreground_color'))
              .accessibilityLevel('no')
          }
            .type(ButtonType.Circle)
            .width(36)
            .height(36)
            .padding(0)
            .backgroundColor($r('app.color.button_background_color'))
            .accessibilityText($r('app.string.common_share'))
            .bindMenu([
              {
                value: $r('app.string.share_full'),
                action: () => {
                  this.shareLink(item.content, false);
                }
              },
              {
                value: $r('app.string.share_link'),
                action: async () => {
                  const link: string = await getShareLink(item.content);
                  this.shareLink(link, true);
                }
              }
            ])

          AdaptiveIconButton({
            icon: $r('app.media.icon_delete'),
            accessibilityLabel: $r('app.string.common_delete'),
            barWidth: 36,
            barHeight: 36,
            iconWidth: 18,
            iconHeight: 18,
            contentPadding: 0,
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
