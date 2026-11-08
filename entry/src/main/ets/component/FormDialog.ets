import { AppErrorDialog } from '../utils/AppErrorDialog';

/**
 * 带内容区（输入框等）的通用对话框基类
 *
 * 由系统提供 @CustomDialog 外壳：标题 + 调用方注入的内容（@BuilderParam）+ 分隔线 +
 * 确认/取消（无背景文字按钮，确认在左、取消在右）。各业务场景只需提供 title、
 * contentBuilder、cancel、confirm，不必重复实现外壳与按钮样式
 *
 * 确认按钮点击后异步执行 confirm；confirm 内部自行决定成功时关闭弹框
 * （controller.close()）、失败时保持打开
 */
@CustomDialog
export struct FormDialog {
  controller: CustomDialogController;
  title: ResourceStr = '';
  @BuilderParam contentBuilder: () => void;
  cancel: () => void = () => {
  };
  confirm: () => Promise<void> = async () => {
  };
  @State private submitting: boolean = false;
  @State private errorMessage: ResourceStr = '';

  aboutToAppear(): void {
    AppErrorDialog.registerInline(this, (message: ResourceStr) => { this.errorMessage = message; });
  }

  aboutToDisappear(): void {
    AppErrorDialog.unregisterInline(this);
  }

  private async submit(): Promise<void> {
    // 异步确认完成前禁止再次提交，避免重复触发
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    this.errorMessage = '';
    try {
      await this.confirm();
    } catch (error) {
      AppErrorDialog.showError(this.getUIContext(), error as Error, $r('app.string.error_unknown'));
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Column() {
      Column() {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 12 })

        this.contentBuilder()
        if (this.errorMessage) {
          Text(this.errorMessage).fontSize(14).fontColor($r('sys.color.warning')).margin({ top: 12 })
        }
      }
      .padding({ left: 24, right: 24, top: 24, bottom: 16 })

      Divider()

      Row() {
        Button($r('app.string.common_confirm'))
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontColor($r('app.color.button_background_color'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.submit();
          })
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(!this.submitting)
          .onClick(() => {
            this.controller.close();
            this.cancel();
          })
      }
    }
  }
}
