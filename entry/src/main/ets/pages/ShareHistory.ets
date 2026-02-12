import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { HistoryItem } from '../model/ShareHistoryModel';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { getShareLink } from '../utils/ParseLinkUtil';
import { DataPreferences } from '@abner/datastore';
import { AUTO_LOCK, BACKGROUND_TIMESTAMP } from '../utils/Constants';
import { EntryRouter } from '../../../../EntryRouter';

@Builder
export function HistoryPageBuilder() {
  History();
}

@Component
struct History {
  pathInfos: NavPathStack = new NavPathStack();
  @State searchText: string = '';
  @State historyList: HistoryItem[] = [];
  @State filteredList: HistoryItem[] = [];
  private dbUtil: ShareDatabaseUtil = ShareDatabaseUtil.getInstance();

  async aboutToAppear() {
    await this.loadHistory();
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
        message: '加载历史记录失败'
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
      return '刚刚';
    } else if (minutes < 60) {
      return `${minutes}分钟前`;
    } else if (hours < 24) {
      return `${hours}小时前`;
    } else if (days < 7) {
      return `${days}天前`;
    } else {
      return date.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit' });
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
        message: `请先转换分享链接`
      });
      return;
    }
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).catch((err: BusinessError) => {
      console.error(`Failed to set paste data. Code is ${err.code}, message is ${err.message}.`);
      this.getUIContext().getPromptAction().showToast({
        message: `复制失败, 错误信息: ${err.message}}`
      });
      return;
    });
    this.getUIContext().getPromptAction().showToast({
      message: `复制成功`
    });
  }

  // 删除功能
  async deleteItem(item: HistoryItem) {
    try {
      await this.dbUtil.deleteData('history', item.id);
      await this.loadHistory(); // 重新加载历史记录
      this.getUIContext().getPromptAction().showToast({
        message: '删除成功'
      });
    } catch (err) {
      console.error(`Failed to delete item. Error: ${JSON.stringify(err)}`);
      this.getUIContext().getPromptAction().showToast({
        message: '删除失败'
      });
    }
  }

  shareLink(text: string, shareLink: boolean) {
    if (text == "") {
      this.getUIContext().getPromptAction().showToast({
        message: `请先转换分享链接`
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
        message: `分享失败, 错误信息: ${err.message}}`
      });
    })
  }

  build() {
    NavDestination() {
      Column() {
        // 搜索栏
        Search({
          value: this.searchText,
          placeholder: '搜索历史记录'
        })
          .searchButton('搜索')
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
            Text('暂无历史记录')
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
    .title('历史记录')
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onHidden(() => {
      DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
    })
    .onShown(() => {
      const autoLockStatus = DataPreferences.getInstance().getSync<number>(AUTO_LOCK);
      if (autoLockStatus == 1) {
        const currentTime = Math.floor(Date.now() / 1000);
        const backgroundTime = DataPreferences.getInstance().getSync<number>(BACKGROUND_TIMESTAMP);
        if (currentTime - backgroundTime > 120) {
          this.pathInfos.pushPath({ name: EntryRouter.UnlockPage });
        }
      }
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
      Button('复制')
        .type(ButtonType.Normal)
        .backgroundColor('#007DFF')
        .width(80)
        .height('33%')
        .bindMenu([
          {
            value: '复制完整内容',
            action: () => {
              this.copyLink(item.content);
            }
          },
          {
            value: '仅复制链接',
            action: async () => {
              const link: string = await getShareLink(item.content);
              this.copyLink(link);
            }
          }
        ])

      Button('分享')
        .type(ButtonType.Normal)
        .backgroundColor('#FFA500')
        .width(80)
        .height('33%')
        .bindMenu([
          {
            value: '分享完整内容',
            action: () => {
              this.shareLink(item.content, false);
            }
          },
          {
            value: '仅分享链接',
            action: async () => {
              const link: string = await getShareLink(item.content);
              this.shareLink(link, true);
            }
          }
        ])

      Button('删除')
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

