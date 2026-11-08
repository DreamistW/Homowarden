import { AppErrorDialog } from '../utils/AppErrorDialog';
import { BackgroundErrorStore } from '../utils/BackgroundErrorStore';

@Component
export struct BackgroundErrorIndicator {
  source: string = 'vault-sync';
  @StorageLink('backgroundErrorRevision') revision: number = 0;

  build() {
    if (this.revision >= 0 && BackgroundErrorStore.hasErrors(this.source)) {
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.icon_background_error'))
          .width(24)
          .height(24)
      }
      .id('background_error_indicator')
      .width(40)
      .height(40)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .accessibilityText($r('app.string.background_error_hint'))
      .onClick(() => AppErrorDialog.show(this.getUIContext(), BackgroundErrorStore.message(this.getUIContext(), this.source)))
    }
  }
}
