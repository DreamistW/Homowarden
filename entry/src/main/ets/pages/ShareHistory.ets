import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { HistoryItem } from '../model/ShareHistoryModel';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { getShareLink } from '../utils/ParseLinkUtil';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';

@Builder
export function HistoryPageBuilder() {
  History();
}

@Component
struct History {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  pathInfos: NavPathStack = new NavPathStack();
  @State searchText: string = '';
  @State historyList: HistoryItem[] = [];
  @State filteredList: HistoryItem[] = [];
  private dbUtil: ShareDatabaseUtil = ShareDatabaseUtil.getInstance();
  private refreshTimer: number = -1;
  private isPageActive: boolean = false;
  private appearanceGeneration: number = 0;

  async aboutToAppear() {
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
      this.filteredList = [...this.filteredList];
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

  // 删除功能
  async deleteItem(item: HistoryItem) {
    try {
      await this.dbUtil.deleteData('history', item.id);
      await this.loadHistory(); // 重新加载历史记录
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.share_delete_success')
      });
    } catch (err) {
      console.error(`Failed to delete item. Error: ${JSON.stringify(err)}`);
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
              .swipeAction({
                end: {
                  builder: this.ActionBuilder.bind(this, item),
                },
                edgeEffect: SwipeEdgeEffect.None
              })
            }, (item: HistoryItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
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
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
  }

  // 历史记录项构建器
  @Builder
  HistoryItemBuilder(item: HistoryItem) {
    Row() {
      Column() {
        Text(item.content)
          .fontSize(16)
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .align(Alignment.Start)
          .width('100%')
          .padding({ right: 12 })

        Text(this.formatTime(item.timestamp))
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 8 })
          .align(Alignment.Start)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })
    }
    .width('100%')
    .borderRadius(8)
    .margin({ left: 16, right: 16 })
  }

  // 滑动操作构建器
  @Builder
  ActionBuilder(item: HistoryItem) {
    Column() {
      Button($r('app.string.common_copy'))
        .type(ButtonType.Normal)
        .backgroundColor('#007DFF')
        .width(80)
        .height('33%')
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

      Button($r('app.string.common_share'))
        .type(ButtonType.Normal)
        .backgroundColor('#FFA500')
        .width(80)
        .height('33%')
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

      Button($r('app.string.common_delete'))
        .type(ButtonType.Normal)
        .backgroundColor('#FF3B30')
        .width(80)
        .height('33%')
        .onClick(() => {
          this.deleteItem(item);
        })
    }
    .width(80)
    .height('100%')
  }
}
