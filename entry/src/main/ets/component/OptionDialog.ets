export interface DialogOption {
  text: ResourceStr;
  value: number;
}

/** 通用选项弹框：标题可选，选项与取消按钮共用登录页按钮样式。 */
@CustomDialog
export struct OptionDialog {
  controller: CustomDialogController;
  title: ResourceStr = '';
  options: DialogOption[] = [];
  onSelect: (value: number) => void = () => {};

  @Builder
  private optionButton(text: ResourceStr, action: () => void) {
    Button(text)
      .type(ButtonType.Normal)
      .width('100%')
      .height(48)
      .borderRadius(8)
      .backgroundColor($r('app.color.translucent_button_background'))
      .fontColor($r('app.color.brand_accent_color'))
      .onClick(action)
  }

  build() {
    Column({ space: 8 }) {
      if (this.title !== '') {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 8 })
      }

      ForEach(this.options, (option: DialogOption) => {
        this.optionButton(option.text, () => {
          this.controller.close();
          this.onSelect(option.value);
        })
      }, (option: DialogOption): string => option.value.toString())

      this.optionButton($r('app.string.common_cancel'), (): void => this.controller.close())
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.option_dialog_background'))
    .borderRadius(24)
  }
}
