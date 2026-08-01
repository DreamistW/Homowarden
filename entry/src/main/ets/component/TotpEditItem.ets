import { IBestToast } from '@ibestservices/ibest-ui';
import { Logger } from '@nzy/logger';
import { TOTPUtil } from '../utils/TOTPUtil';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AdaptiveIconButton } from './AdaptiveButton';

/**
 * TOTP密钥编辑组件
 * 仅支持扫码录入和清除密钥
 */
@Component
export struct TotpEditItem {
  @Link totpSecret: string;
  onSecretChange?: (secret: string) => void;

  /**
   * 扫描二维码录入TOTP密钥
   */
  private async scanQRCode() {
    try {
      // 定义扫码参数options
      let options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true
      };

      scanBarcode.startScanForResult(this.getUIContext().getHostContext(), options)
        .then((result: scanBarcode.ScanResult) => {
          if (result && result.originalValue) {
            Logger.info(`Scan result: ${result.originalValue}`);

            // 尝试解析otpauth URL
            const parsed = TOTPUtil.parseOtpAuthUrl(result.originalValue);

            if (parsed.secret) {
              this.totpSecret = parsed.secret;
              this.onSecretChange?.(parsed.secret);
              Logger.info(`TOTP secret extracted: ${parsed.secret}`);

              if (parsed.issuer || parsed.account) {
                IBestToast.show($r('app.string.totp_scan_success', parsed.issuer ?? parsed.account ?? ''));
              } else {
                IBestToast.show($r('app.string.totp_entered'));
              }
            } else {
              IBestToast.show($r('app.string.totp_invalid'));
            }
          }
        })
        .catch((error: BusinessError) => {
          Logger.error(`Failed to start the scanning service. Code:${error.code}, message: ${error.message}`);
        })
    } catch (error) {
      Logger.error(`Start scan failed: ${JSON.stringify(error)}`);
      IBestToast.show($r('app.string.error_unknown'));
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
                IBestToast.show($r('app.string.common_success'));
              }
            })

            // Button() {
            //   Image($r('app.media.icon_cancel'))
            //     .width(18)
            // }
            // .backgroundColor(Color.Transparent)
            // .margin({ left: 8, right: 8 })
            // .onClick(() => {
            //   this.totpSecret = '';
            //   this.onSecretChange?.('');
            //   IBestToast.show('密钥已清除');
            // })
          }

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

          // Button() {
          //   Image($r('app.media.icon_scan_barcode'))
          //     .width(18)
          // }
          // .backgroundColor(Color.Transparent)
          // .onClick(() => this.scanQRCode())
          // .margin({ right: 8 })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
