import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';
import { hdsMaterial, HdsNavDestination, HdsNavigationBadgeIconOptions } from '@kit.UIDesignKit';
import { GeneratorDatabaseUtil, GENERATOR_HISTORY_TABLE } from '../utils/GeneratorDatabaseUtil';
import { GeneratorHistoryItem, GeneratorRecordType } from '../model/GeneratorHistoryModel';
import { AdaptiveIconButton } from '../component/AdaptiveButton';
import { AppToast } from '../utils/AppToast';

@Builder
export function GeneratorHistoryPageBuilder() {
  GeneratorHistory();
}

@Component
struct GeneratorHistory {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  pathInfos: NavPathStack = new NavPathStack();
  @State historyList: GeneratorHistoryItem[] = [];
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
    this.getUIContext().showAlertDialog({
      title: $r('app.string.generator_history_delete_confirm'),
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

  // 弹出确认对话框请求清空全部记录。
  private requestClearAll(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.common_confirm'),
      message: $r('app.string.generator_history_clear_confirm'),
      secondaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {}
      },
      primaryButton: {
        value: $r('app.string.common_confirm'),
        action: () => {
          void this.doClearAll();
        }
      }
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

      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: {
          mainTitle: $r('app.string.generator_history_title')
        },
        menu: { value: [this.clearBtn] }
      },
      enableComponentSafeArea: true,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
  }

  // 单条历史记录卡片
  @Builder
  HistoryItemBuilder(item: GeneratorHistoryItem) {
    Row() {
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
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.start_window_background'))
  }

}
