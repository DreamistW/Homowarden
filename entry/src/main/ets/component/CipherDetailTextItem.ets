import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { PromptAction } from '@kit.ArkUI';
import { Logger } from '@nzy/logger';

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
      } else {
        Text(this.content ? (this.showContent ? this.content : this.placeholder) : '')
          .fontSize(14)
          .layoutWeight(1)
      }

      if (this.showHideButton && !this.isEditable && this.content) {
        Button() {
          Text(this.showContent ? '隐藏' : '显示')
            .fontSize(12)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.showContent = !this.showContent)
        .margin({ right: 8 })
      }

      if (this.showCopyButton && !this.isEditable && this.content) {
        Button() {
          Text('复制')
            .fontSize(12)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.copyText(this.content));
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
      let promptAction: PromptAction = this.getUIContext().getPromptAction();
      promptAction.showToast({
        message: '已复制',
        duration: 2000
      })
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to paste, error message: ${err.message}}`);
    }
  }
}