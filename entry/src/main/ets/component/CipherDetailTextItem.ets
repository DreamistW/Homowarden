import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { AppToast } from '../utils/AppToast';
import { Logger } from '@nzy/logger';
import { common, Want } from '@kit.AbilityKit';
import { AdaptiveIconButton } from './AdaptiveButton';

@Component
export struct CipherDetailTextItem {
  // 文本标题
  @Prop label: ResourceStr;
  // 显示文本内容
  @Prop content: string;
  // 是否显示敏感信息（控制明文/星号切换）
  @Prop showContent: boolean = true;
  // 是否显示隐藏按钮
  @Prop showHideButton: boolean = false;
  // 是否显示复制按钮
  @Prop showCopyButton: boolean = true;
  // 占位符样式
  @Prop placeholder: ResourceStr = '••••••••';
  // 是否编辑模式
  @Prop isEditable: boolean = false;
  // 是否只能输入数字
  @Prop isNumberOnly: boolean = false;
  // 是否链接
  @Prop isUri: boolean = false;
  // 内容变化回调
  onValueChange?: (value: string) => void;

  build() {
    Row() {
      Text(this.label)
        .fontSize(14)
        .fontColor('#666666')
        .width(112)

      if (this.isEditable) {
        TextInput({ text: this.content })
          .accessibilityText(this.getAccessibilityLabel())
          .fontSize(14)
          .layoutWeight(1)
          .margin({ left: 16, right: 16 })
          .onChange((value: string) => {
            if (this.onValueChange) {
              this.onValueChange(value);
            }
          })
          .type((this.showHideButton ? InputType.Password : InputType.Normal) |
            (this.isNumberOnly ? InputType.Number : InputType.Normal))
        if (this.isUri) {
          Column() {
            AdaptiveIconButton({
              icon: $r('app.media.icon_cancel'),
              accessibilityLabel: $r('app.string.accessibility_clear'),
              barWidth: 40,
              barHeight: 40,
              iconWidth: 20,
              iconHeight: 20,
              contentPadding: 6,
              barBottomMargin: 0,
              onButtonClick: () => {
                this.doClearUri();
              }
            })
          }

        }
      } else {
        Text(this.content ? (this.showContent ? this.content : this.placeholder) : '')
          .fontSize(14)
          .layoutWeight(1)
      }

      if (this.showHideButton && !this.isEditable && this.content) {
        if (this.showContent) {
          AdaptiveIconButton({
            icon: $r('app.media.icon_show'),
            accessibilityLabel: $r('app.string.accessibility_hide'),
            barWidth: 40,
            barHeight: 40,
            iconWidth: 20,
            iconHeight: 20,
            contentPadding: 6,
            barBottomMargin: 0,
            onButtonClick: () => {
              this.showContent = false;
            }
          })
        } else {
          AdaptiveIconButton({
            icon: $r('app.media.icon_hide'),
            accessibilityLabel: $r('app.string.accessibility_show'),
            barWidth: 40,
            barHeight: 40,
            iconWidth: 20,
            iconHeight: 20,
            contentPadding: 6,
            barBottomMargin: 0,
            onButtonClick: () => {
              this.showContent = true;
            }
          })
        }
      }

      if (this.showCopyButton && !this.isEditable && this.content) {
        AdaptiveIconButton({
          icon: $r('app.media.icon_copy'),
          accessibilityLabel: $r('app.string.common_copy'),
          barWidth: 40,
          barHeight: 40,
          iconWidth: 20,
          iconHeight: 20,
          contentPadding: 6,
          barBottomMargin: 0,
          onButtonClick: () => {
            this.copyText(this.content);
          }
        })
      }

      if (this.isUri && !this.isEditable) {
        AdaptiveIconButton({
          icon: $r('app.media.icon_jump'),
          accessibilityLabel: $r('app.string.accessibility_open_website'),
          barWidth: 40,
          barHeight: 40,
          iconWidth: 20,
          iconHeight: 20,
          contentPadding: 6,
          barBottomMargin: 0,
          onButtonClick: () => {
            this.doUriJump();
          }
        })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  private getAccessibilityLabel(): string {
    if (typeof this.label === 'string') {
      return this.label;
    }
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(this.label.id) ?? '';
  }

  private async copyText(text: string | null | undefined) {
    if (text == undefined || !text) {
      return;
    }
    try {
      // 密码等明文只在用户点击复制时进入系统剪贴板
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      AppToast.show(this.getUIContext(), $r('app.string.totp_copied'));
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to paste, error message: ${err.message}}`);
    }
  }

  private async doUriJump() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) {
        AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
        return;
      }

      // Want 需要完整 URI；兼容历史数据中未保存协议前缀的网址
      let uri = this.content;
      if (!this.content.startsWith('http://') && !this.content.startsWith('https://')) {
        // 如果没有协议前缀，添加前缀
        uri = 'http://' + this.content;
      }

      const want: Want = {
        uri: uri
      };
      context.startAbility(want).catch((err: Error) => {
        Logger.error(`Failed to open uri. Error: ${err.message}`);
        AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
      });
    } catch (err) {
      Logger.error(`Failed to open uri. Error: ${JSON.stringify(err)}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
    }
  }

  private doClearUri() {
    this.content = '';
  }
}
