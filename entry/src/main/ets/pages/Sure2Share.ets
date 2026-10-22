import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { inputMethod } from '@kit.IMEKit';
import { getFullLink, getShareLink, replaceOutputText } from '../utils/ParseLinkUtil';
import { Logger } from '@nzy/logger';
import { AppToast } from '../utils/AppToast';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { AdaptiveMenuTextButton, AdaptivePasteButton, AdaptiveTextButton } from '../component/AdaptiveButton';

@Component
export struct Sure2SharePage {
  @Prop bottomContentInset: number = 0;
  @State inputText: string = '';
  @State outputText: string = '';

  /**
   * 解析原始分享文本、展开短链并去除跟踪信息，成功后写入历史记录
   */
  async convertLink() {
    const shareLink = await getShareLink(this.inputText);
    if (shareLink == "") {
      AppToast.show(this.getUIContext(), $r('app.string.share_no_link'));
      return;
    }
    const fullLink = await getFullLink(shareLink);
    if (fullLink == "") {
      AppToast.show(this.getUIContext(), $r('app.string.error_network'), true);
      return;
    }
    this.outputText = await replaceOutputText(this.inputText, fullLink);
    if (this.outputText == "") {
      AppToast.show(this.getUIContext(), $r('app.string.error_unknown'));
      return;
    }
    AppToast.show(this.getUIContext(), $r('app.string.share_convert_success'));
    // 转换结果不含密码库密文，但可能包含用户分享内容，仅写入应用本地历史库
    const dbUtil = ShareDatabaseUtil.getInstance();
    const item: relationalStore.ValuesBucket = {
      id: dbUtil.generateId(),
      content: this.outputText,
      timestamp: Date.now()
    }
    dbUtil.insertData('history', item);
  }

  /**
   * 将转换结果写入系统剪贴板，跨应用暴露由用户显式触发
   */
  async copyLink(text: string): Promise<void> {
    if (text == "") {
      AppToast.show(this.getUIContext(), $r('app.string.share_convert_first'));
      return;
    }
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    try {
      await systemPasteboard.setData(pasteData);
      AppToast.show(this.getUIContext(), $r('app.string.share_copy_success'));
    } catch (err) {
      Logger.error(`Failed to set paste data: ${err}`);
      AppToast.show(this.getUIContext(), $r('app.string.share_copy_failed'));
    }
  }

  /**
   * 根据内容类型拉起系统分享面板，不在应用内选择或缓存接收方
   */


  build() {
    Scroll() {
      Column() {
          Text($r('app.string.share_help'))
            .alignRules({
              middle: { anchor: '__container__', align: HorizontalAlign.Center }
            })
            .margin({
              left: "5%",
              right: "5%",
              bottom: "10%"
            })
          // 输入标题
          Text($r('app.string.share_input_title'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .align(Alignment.Start)
            .width('90%')

          // 输入文本框
          TextArea({ text: this.inputText })
            .accessibilityText($r('app.string.share_input_title'))
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
              translucent: true,
              onPaste: (text: string) => {
                this.inputText = text;
                this.convertLink();
              },
              onPasteError: (err: BusinessError) => {
                Logger.error(`Failed to get paste data. Code is ${err.code}, message is ${err.message}.`);
              }
            })

            AdaptiveTextButton({
              text: $r('app.string.share_convert'),
              barWidth: 144,
              barHeight: 50,
              fontSize: 16,
              contentPadding: 6,
              barBottomMargin: 0,
              translucent: true,
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
          Text($r('app.string.share_output_title'))
            .id('afterLink')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .align(Alignment.Start)
            .width('90%')
            .margin({ top: 40 })

          // 输出文本框
          TextArea({ text: this.outputText })
            .accessibilityText($r('app.string.share_output_title'))
            .height('20%')
            .width('90%')
            .margin({ top: 12, bottom: 12 })
            .focusable(false)

          Row({ space: 0 }) {
            AdaptiveMenuTextButton({
              text: $r('app.string.common_copy'),
              barWidth: 144,
              barHeight: 50,
              fontSize: 16,
              contentPadding: 6,
              barBottomMargin: 0,
              translucent: true,
              menuItems: [
                {
                  value: $r('app.string.share_copy_full'),
                  action: () => {
                    this.copyLink(this.outputText);
                  }
                },
                {
                  value: $r('app.string.share_copy_link'),
                  action: async () => {
                    const link: string = await getShareLink(this.outputText);
                    this.copyLink(link);
                  }
                }
              ]
            })


          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
      }
      .padding({ left: 20, right: 20, top: 20, bottom: 20 + this.bottomContentInset })
      .width('100%')
    }
    .scrollBar(BarState.Auto)
    .scrollable(ScrollDirection.Vertical)
    .width('100%')
    .height('100%')
  }
}
