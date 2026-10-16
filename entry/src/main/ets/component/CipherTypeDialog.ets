import { CipherItemType } from '../utils/Constants';

/** 新建密码项的类型选择，每种类型独占一个按钮行。 */
@CustomDialog
export struct CipherTypeDialog {
  controller: CustomDialogController;
  onSelect: (type: CipherItemType) => void = () => {};

  @Builder
  private typeButton(type: CipherItemType, label: Resource) {
    Button(label, { type: ButtonType.Normal })
      .width('100%')
      .height(48)
      .borderRadius(12)
      .fontSize(16)
      .backgroundColor($r('app.color.secondary_button_background_color'))
      .fontColor($r('app.color.secondary_button_foreground_color'))
      .onClick(() => {
        this.controller.close();
        this.onSelect(type);
      })
  }

  build() {
    Column({ space: 12 }) {
      Text($r('app.string.cipher_add_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      this.typeButton(CipherItemType.LOGIN, $r('app.string.vault_type_login'))
      this.typeButton(CipherItemType.NOTE, $r('app.string.vault_type_note'))
      this.typeButton(CipherItemType.CARD, $r('app.string.vault_type_card'))
      this.typeButton(CipherItemType.IDENTITY, $r('app.string.vault_type_identity'))

      Divider().margin({ top: 4 })
      Button($r('app.string.common_cancel'), { type: ButtonType.Normal })
        .width('100%')
        .height(48)
        .borderRadius(12)
        .fontSize(16)
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .onClick(() => this.controller.close())
    }
    .width('100%')
    .padding(24)
  }
}
