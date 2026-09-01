import { AppToast } from '../utils/AppToast';
import { Logger } from '@nzy/logger';
import { TOTPUtil } from '../utils/TOTPUtil';
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AdaptiveIconButton, AdaptiveTextButton } from './AdaptiveButton';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { FormFactorUtil } from '../utils/FormFactorUtil';

/**
 * TOTP密钥编辑组件
 * 仅支持扫码录入和清除密钥
 */
@Component
export struct TotpEditItem {
  @Link totpSecret: string;
  onSecretChange?: (secret: string) => void;
  private isPc: boolean = FormFactorUtil.isPc();

  private applyScanResult(originalValue: string): void {
    const parsed = TOTPUtil.parseOtpAuthUrl(originalValue);
    if (!parsed.secret) {
      AppToast.show(this.getUIContext(), $r('app.string.totp_import_failed_invalid_uri'));
      return;
    }

    this.totpSecret = parsed.secret;
    this.onSecretChange?.(parsed.secret);
    Logger.info('TOTP secret extracted successfully');
    AppToast.show(this.getUIContext(), $r('app.string.totp_import_success'));
  }

  private showImportFailure(error: BusinessError): void {
    const detail = error.message || error.code?.toString() || 'Unknown error';
    AppToast.show(this.getUIContext(), $r('app.string.totp_import_failed', detail));
  }

  /**
   * 扫描二维码录入TOTP密钥
   */
  private async scanQRCode(): Promise<void> {
    try {
      // 定义扫码参数options
      let options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true
      };

      await scanBarcode.startScanForResult(this.getUIContext().getHostContext(), options)
        .then((result: scanBarcode.ScanResult) => {
          if (result && result.originalValue) {
            Logger.info('TOTP QR code scanned');
            // 只从标准 otpauth URL 提取密钥，不把完整扫码内容直接写入密码项
            this.applyScanResult(result.originalValue);
          }
        });
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Start scan failed. Code:${businessError.code}, message: ${businessError.message}`);
      this.showImportFailure(businessError);
    }
  }

  /** PC 端通过系统图库选择二维码图片，再使用 Scan Kit 解析其中的 otpauth URI。 */
  private async selectQrImage(): Promise<void> {
    try {
      const pickerOptions = new photoAccessHelper.PhotoSelectOptions();
      pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      pickerOptions.maxSelectNumber = 1;
      pickerOptions.isPhotoTakingSupported = false;
      pickerOptions.isEditSupported = false;

      const picker = new photoAccessHelper.PhotoViewPicker();
      const selection = await picker.select(pickerOptions);
      if (!selection.photoUris || selection.photoUris.length === 0) {
        return;
      }

      const scanResults = await detectBarcode.decode({ uri: selection.photoUris[0] }, {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: false
      });
      const totpResult = scanResults.find((result: scanBarcode.ScanResult) => {
        return result.originalValue?.toLowerCase().startsWith('otpauth://');
      });
      if (!totpResult?.originalValue) {
        AppToast.show(this.getUIContext(), $r('app.string.totp_import_failed_no_qr'));
        return;
      }

      Logger.info('TOTP QR code imported from image');
      this.applyScanResult(totpResult.originalValue);
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Failed to import TOTP QR image. Code:${businessError.code}, message: ${businessError.message}`);
      this.showImportFailure(businessError);
    }
  }

  build() {
    Column() {
      // 标签
      Text($r('app.string.totp_title'))
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Center)
        .margin({ bottom: 8 })

      // 密钥显示行（只读，密码类型）
      Row() {
        TextInput({
          text: this.totpSecret,
          placeholder: this.totpSecret ? $r('app.string.totp_entered') : $r('app.string.totp_not_entered')
        })
          .accessibilityText($r('app.string.totp_title'))
          .type(InputType.Password)
          .layoutWeight(1)
          .margin({ right: 8 })
          .focusable(false)

        Row({ space: 0 }) {
          // 清除按钮（仅当有密钥时显示）
          if (this.totpSecret && this.totpSecret.length > 0) {
            AdaptiveIconButton({
              icon: $r('app.media.icon_cancel'),
              accessibilityLabel: $r('app.string.accessibility_clear_totp'),
              barWidth: 40,
              barHeight: 40,
              iconWidth: 20,
              iconHeight: 20,
              contentPadding: 6,
              barBottomMargin: 0,
              onButtonClick: () => {
                this.totpSecret = '';
                this.onSecretChange?.('');
                AppToast.show(this.getUIContext(), $r('app.string.common_success'));
              }
            })

          }

          if (this.isPc) {
            AdaptiveTextButton({
              text: $r('app.string.totp_import_image'),
              barWidth: 120,
              barHeight: 40,
              fontSize: 14,
              contentPadding: 6,
              barBottomMargin: 0,
              translucent: true,
              onButtonClick: () => {
                void this.selectQrImage();
              }
            })
          } else {
            AdaptiveIconButton({
              icon: $r('app.media.icon_scan_barcode'),
              accessibilityLabel: $r('app.string.accessibility_scan_totp'),
              barWidth: 40,
              barHeight: 40,
              iconWidth: 20,
              iconHeight: 20,
              contentPadding: 6,
              barBottomMargin: 0,
              onButtonClick: () => {
                this.scanQRCode()
              }
            })
          }

        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
