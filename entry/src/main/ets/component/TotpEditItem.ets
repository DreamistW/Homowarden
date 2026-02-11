import { IBestToast } from '@ibestservices/ibest-ui';
import { Logger } from '@nzy/logger';
import { TOTPUtil } from '../utils/TOTPUtil';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';

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
                IBestToast.show(`密钥已录入${parsed.issuer ? ': ' + parsed.issuer : ''}`);
              } else {
                IBestToast.show('密钥已录入');
              }
            } else {
              IBestToast.show('无效的验证码二维码');
            }
          }
        })
        .catch((error: BusinessError) => {
          Logger.error(`Failed to start the scanning service. Code:${error.code}, message: ${error.message}`);
        })
    } catch (error) {
      Logger.error(`Start scan failed: ${JSON.stringify(error)}`);
      IBestToast.show('启动扫码失败');
    }
  }

  build() {
    Column() {
      // 标签
      Text('TOTP密钥')
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Center)
        .margin({ bottom: 8 })

      // 密钥显示行（只读，密码类型）
      Row() {
        TextInput({
          text: this.totpSecret,
          placeholder: this.totpSecret ? '已录入密钥' : '请扫码录入TOTP密钥'
        })
          .type(InputType.Password)
          .layoutWeight(1)
          .margin({ right: 8 })
          .focusable(false)

        // 清除按钮（仅当有密钥时显示）
        if (this.totpSecret && this.totpSecret.length > 0) {
          Button() {
            Image($r('app.media.icon_cancel'))
              .width(18)
          }
          .backgroundColor(Color.Transparent)
          .margin({ left: 8, right: 8 })
          .onClick(() => {
            this.totpSecret = '';
            this.onSecretChange?.('');
            IBestToast.show('密钥已清除');
          })
        }

        Button() {
          Image($r('app.media.icon_scan_barcode'))
            .width(18)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.scanQRCode())
        .margin({ right: 8 })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
