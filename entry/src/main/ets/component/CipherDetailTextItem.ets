import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { IBestToast } from '@ibestservices/ibest-ui';
import { Logger } from '@nzy/logger';
import { common, Want } from '@kit.AbilityKit';

@Component
export struct CipherDetailTextItem {
  // 文本标题
  @Prop label: string;
  // 显示文本内容
  @Prop content: string;
  // 是否显示敏感信息（控制明文/星号切换）
  @Prop showContent: boolean = true;
  // 是否显示隐藏按钮
  @Prop showHideButton: boolean = false;
  // 是否显示复制按钮
  @Prop showCopyButton: boolean = true;
  // 占位符样式
  @Prop placeholder: string = '••••••••';
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
        .width(80)

      if (this.isEditable) {
        TextInput({ text: this.content })
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
          Button() {
            Image($r('app.media.icon_cancel'))
              .width(18)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => this.doClearUri())
          .margin({ right: 8 })
        }
      } else {
        Text(this.content ? (this.showContent ? this.content : this.placeholder) : '')
          .fontSize(14)
          .layoutWeight(1)
      }

      if (this.showHideButton && !this.isEditable && this.content) {
        Button() {
          Image(this.showContent ? $r('app.media.icon_show') : $r('app.media.icon_hide'))
            .width(18)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.showContent = !this.showContent)
        .margin({ right: 8 })
      }

      if (this.showCopyButton && !this.isEditable && this.content) {
        Button() {
          Image($r('app.media.icon_copy'))
            .width(18)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.copyText(this.content))
        .margin({ right: 8 })
      }

      if (this.isUri && !this.isEditable) {
        Button() {
          Image($r('app.media.icon_jump'))
            .width(18)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.doUriJump())
        .margin({ right: 8 })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  private async copyText(text: string | null | undefined) {
    if (text == undefined || !text) {
      return;
    }
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      IBestToast.show('已复制');
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to paste, error message: ${err.message}}`);
    }
  }

  private async doUriJump() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) {
        IBestToast.show('无法跳转到网站');
        return;
      }

      // 检查网址是否有前缀
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
        IBestToast.show(`无法跳转到网站, 错误信息: ${err.message}`);
      });
    } catch (err) {
      Logger.error(`Failed to open uri. Error: ${JSON.stringify(err)}`);
      IBestToast.show(`无法跳转到网站, 错误信息: ${JSON.stringify(err)}`);
    }
  }

  private doClearUri() {
    this.content = '';
  }
}