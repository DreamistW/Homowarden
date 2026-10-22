import { AppToast } from '../utils/AppToast';
import { LogExportService } from '../utils/LogExportService';
import { pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';

/** 登录页与设置页共用的日志导出确认弹窗。 */
@CustomDialog
export struct LogExportDialog {
  controller: CustomDialogController;
  @State private submitting: boolean = false;

  private async exportLogs(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      const uiContext = this.getUIContext();
      const success = await LogExportService.exportFile(uiContext);
      if (success) {
        this.controller.close();
        AppToast.show(uiContext, $r('app.string.log_export_ready'));
      } else {
        AppToast.show(this.getUIContext(), $r('app.string.log_export_failed'));
      }
    } finally {
      this.submitting = false;
    }
  }

  private async copyMessage(): Promise<void> {
    try {
      const resourceManager = this.getUIContext().getHostContext()?.resourceManager;
      if (!resourceManager) {
        throw new Error('Resource manager is unavailable');
      }
      const message = await resourceManager.getStringValue($r('app.string.log_export_message').id);
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, message);
      await pasteboard.getSystemPasteboard().setData(data);
      AppToast.show(this.getUIContext(), $r('app.string.share_copy_success'));
    } catch (error) {
      Logger.error(`Failed to copy log export instructions: ${error}`);
      AppToast.show(this.getUIContext(), $r('app.string.share_copy_failed'));
    }
  }

  build() {
    Column() {
      Column() {
        Text($r('app.string.log_export_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 12 })
        Text($r('app.string.log_export_message'))
          .fontSize(16)
      }
      .padding({ left: 24, right: 24, top: 24, bottom: 16 })

      Divider()

      Row() {
        Button($r('app.string.log_export_confirm'))
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontColor($r('app.color.button_background_color'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.exportLogs();
          })
        Button($r('app.string.common_copy'))
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.copyMessage();
          })
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(!this.submitting)
          .onClick(() => {
            this.controller.close();
          })
      }
    }
  }
}
