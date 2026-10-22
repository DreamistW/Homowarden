import { AppToast } from '../utils/AppToast';
import { TOTPUtil } from '../utils/TOTPUtil';
import { AdaptiveIconButton, AdaptivePasteButton } from './AdaptiveButton';
import { QrScannerDialog } from './QrScannerDialog';
import { TotpScanResult } from '../utils/TotpScanResult';

/** Standard input and secure paste entry for TOTP secrets. */
@Component
export struct TotpEditItem {
  @Link totpSecret: string;
  onSecretChange?: (secret: string) => void;
  private scanner: CustomDialogController = new CustomDialogController({
    builder: QrScannerDialog({
      selectResult: (values: string[]) => TotpScanResult.findUri(values),
      onDecoded: (value: string) => this.setSecret(value)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  aboutToDisappear(): void {
    this.scanner.close();
  }

  private setSecret(value: string): void {
    const text = value.trim();
    if (text.toLowerCase().startsWith('otpauth://')) {
      const parsed = TOTPUtil.parseOtpAuthUrl(text);
      if (!parsed.secret) {
        AppToast.show(this.getUIContext(), $r('app.string.totp_import_failed_invalid_uri'));
        return;
      }
      this.totpSecret = parsed.secret;
    } else {
      this.totpSecret = text;
    }
    this.onSecretChange?.(this.totpSecret);
  }

  build() {
    Column() {
      Text($r('app.string.totp_title'))
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Center)
        .margin({ bottom: 4 })
      Row({ space: 8 }) {
        AdaptiveIconButton({
          icon: $r('app.media.icon_scan_barcode'),
          accessibilityLabel: $r('app.string.scanner_title'),
          barWidth: 40,
          barHeight: 40,
          contentPadding: 0,
          barBottomMargin: 0,
          onButtonClick: (): void => { this.scanner.open(); }
        })
        TextInput({ text: this.totpSecret, placeholder: $r('app.string.totp_manual_hint') })
          .accessibilityText($r('app.string.totp_title'))
          .type(InputType.Password)
          .layoutWeight(1)
          .onChange((value: string) => this.setSecret(value))
        AdaptivePasteButton({
          barWidth: 64,
          barHeight: 40,
          contentPadding: 0,
          barBottomMargin: 0,
          onPaste: (text: string) => this.setSecret(text),
          onPasteError: () => AppToast.show(this.getUIContext(), $r('app.string.share_copy_failed'))
        })
        if (this.totpSecret.length > 0) {
          AdaptiveIconButton({
            icon: $r('app.media.icon_cancel'),
            accessibilityLabel: $r('app.string.accessibility_clear_totp'),
            barWidth: 40,
            barHeight: 40,
            iconWidth: 20,
            iconHeight: 20,
            contentPadding: 0,
            barBottomMargin: 0,
            onButtonClick: () => this.setSecret('')
          })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 12, bottom: 0 })
  }
}
