/**
 * 通用确认对话框：可选标题 + 消息 + 确认/取消（无背景文字按钮），@CustomDialog 可由
 * controller.close() 关闭。message/title/confirmText 经 @Link 双向绑定，便于同一页面
 * 用一个控制器复用多种确认场景；确认按钮在左、取消在右（与 AlertDialog 顺序一致）
 *
 * 调用方持有 message/title/confirmText 的 @State 与一个 confirmAction 字段，弹前赋值、
 * 再 controller.open()；页面销毁（如旋转跨栈迁移）时 controller 随之失效即等同取消
 */
@CustomDialog
export struct ConfirmDialog {
  controller: CustomDialogController;
  @Link message: ResourceStr;
  @Link title: ResourceStr;
  @Link confirmText: ResourceStr;
  showCancel: boolean = true;
  onConfirm: () => Promise<boolean> = async () => {
    return true;
  };
  onCancel: () => void = () => {
  };
  @State private submitting: boolean = false;

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      if (await this.onConfirm()) {
        this.controller.close();
      }
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Column() {
      Column() {
        if (this.title) {
          Text(this.title)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 12 })
        }
        Text(this.message)
          .fontSize(16)
      }
      .padding({ left: 24, right: 24, top: 24, bottom: 16 })

      Divider()

      Row() {
        Button(this.confirmText)
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontColor($r('app.color.button_background_color'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.submit();
          })
        if (this.showCancel) {
          Button($r('app.string.common_cancel'))
            .layoutWeight(1)
            .height(48)
            .fontSize(16)
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .enabled(!this.submitting)
            .onClick(() => {
              this.onCancel();
              this.controller.close();
            })
        }
      }
    }
  }
}
