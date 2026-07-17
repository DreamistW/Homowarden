import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { relationalStore, uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { inputMethod } from '@kit.IMEKit';
import { getFullLink, getShareLink, replaceOutputText } from '../utils/ParseLinkUtil';
import { EntryRouter } from '../../../../EntryRouter';
import { Logger } from '@nzy/logger';
import { IBestToast } from '@ibestservices/ibest-ui';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { hdsMaterial, HdsNavDestination, HdsNavigationBadgeIconOptions } from '@kit.UIDesignKit';
import { AdaptiveMenuTextButton, AdaptivePasteButton, AdaptiveTextButton } from '../component/AdaptiveButton';

@Builder
export function Sure2SharePageBuilder() {
  Sure2SharePage();
}

@Component
export struct Sure2SharePage {
  @State hint: string =
    '你可以把分享链接复制到这里, 它会帮你去除链接中的跟踪信息。\n目前支持淘宝、京东、哔哩哔哩、小红书、抖音等平台的分享链接。';
  @State inputText: string = '';
  @State outputText: string = '';
  pathInfos: NavPathStack = new NavPathStack();
  historyBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: 'History',
      icon: $r('app.media.icon_history'),
      action: () => {
        this.pathInfos.pushPath({ name: EntryRouter.ShareHistoryPage });
      }
    }
  }

  async convertLink() {
    const shareLink = await getShareLink(this.inputText);
    if (shareLink == "") {
      IBestToast.show(`没有发现分享链接`);
      return;
    }
    const fullLink = await getFullLink(shareLink);
    if (fullLink == "") {
      IBestToast.show(`获取完整链接失败`);
      return;
    }
    this.outputText = await replaceOutputText(this.inputText, fullLink);
    if (this.outputText == "") {
      IBestToast.show(`替换链接失败`);
      return;
    }
    IBestToast.show(`转换成功, 已保存至历史记录`);
    // 写入记录到数据库
    const dbUtil = ShareDatabaseUtil.getInstance();
    const item: relationalStore.ValuesBucket = {
      id: dbUtil.generateId(),
      content: this.outputText,
      timestamp: Date.now()
    }
    dbUtil.insertData('history', item);
  }

  copyLink(text: string) {
    if (text == "") {
      IBestToast.show(`请先转换分享链接`);
      return;
    }
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).catch((err: BusinessError) => {
      Logger.error(`Failed to set paste data. Code is ${err.code}, message is ${err.message}.`);
      IBestToast.show(`复制失败, 错误信息: ${err.message}}`);
      return;
    });
    IBestToast.show(`复制成功`);
  }

  shareLink(text: string, shareLink: boolean) {
    if (text == "") {
      IBestToast.show(`请先转换分享链接`);
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
      Logger.error(`Failed to show share panel. Code is ${err.code}, message is ${err.message}.`);
      IBestToast.show(`分享失败, 错误信息: ${err.message}`);
    })
  }

  build() {
    HdsNavDestination() {
      Scroll() {
        Column() {
          Text(this.hint)
            .alignRules({
              middle: { anchor: '__container__', align: HorizontalAlign.Center }
            })
            .margin({
              left: "5%",
              right: "5%",
              bottom: "10%"
            })
          // 输入标题
          Text('粘贴分享链接')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .align(Alignment.Start)
            .width('90%')

          // 输入文本框
          TextArea({ text: this.inputText })
            .id('beforeLink')
            .height('20%')
            .width('90%')
            .margin({ top: 12, bottom: 12 })
            .onChange((value: string) => {
              this.inputText = value;
            })

          Row({ space: 0 }) {
            AdaptivePasteButton({
              barWidth: 144,
              barHeight: 50,
              fontSize: 16,
              contentPadding: 6,
              barBottomMargin: 0,
              onPaste: (text: string) => {
                this.inputText = text;
                this.convertLink();
              },
              onPasteError: (err: BusinessError) => {
                Logger.error(`Failed to get paste data. Code is ${err.code}, message is ${err.message}.`);
              }
            })

            AdaptiveTextButton({
              text: '转换',
              barWidth: 144,
              barHeight: 50,
              fontSize: 16,
              contentPadding: 6,
              barBottomMargin: 0,
              onButtonClick: () => {
                try {
                  inputMethod.getController().stopInputSession();
                } catch (err) {
                  Logger.error(`Failed to stop input session. Code is ${err.code}, message is ${err.message}.`);
                  return;
                }
                this.convertLink();
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          // 输出标题
          Text('转换后的链接')
            .id('afterLink')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .align(Alignment.Start)
            .width('90%')
            .margin({ top: 40 })

          // 输出文本框
          TextArea({ text: this.outputText })
            .height('20%')
            .width('90%')
            .margin({ top: 12 })
            .focusable(false)

          Row({ space: 0 }) {
            AdaptiveMenuTextButton({
              text: '复制',
              barWidth: 144,
              barHeight: 50,
              fontSize: 16,
              contentPadding: 6,
              barBottomMargin: 0,
              menuItems: [
                {
                  value: '复制完整内容',
                  action: () => {
                    this.copyLink(this.outputText);
                  }
                },
                {
                  value: '仅复制链接',
                  action: async () => {
                    const link: string = await getShareLink(this.outputText);
                    this.copyLink(link);
                  }
                }
              ]
            })

            AdaptiveMenuTextButton({
              text: '分享',
              barWidth: 144,
              barHeight: 50,
              fontSize: 16,
              contentPadding: 6,
              barBottomMargin: 0,
              menuItems: [
                {
                  value: '分享完整内容',
                  action: () => {
                    this.shareLink(this.outputText, false);
                  }
                },
                {
                  value: '仅分享链接',
                  action: async () => {
                    const link: string = await getShareLink(this.outputText);
                    this.shareLink(link, true);
                  }
                }
              ]
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .padding(20)
        .width('100%')
      }
      .scrollBar(BarState.Auto)
      .scrollable(ScrollDirection.Vertical)
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: {
          mainTitle: '安心分享'
        },
        menu: { value: [this.historyBtn] }
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
}
