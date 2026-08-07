import { common } from '@kit.AbilityKit';

@Builder
export function DetailPlaceholderBuilder() {
  DetailPlaceholder();
}

/** 分栏未选择内容时仅展示弱化的应用图标。 */
@Component
export struct DetailPlaceholder {
  private exitTime: number = 0;

  build() {
    NavDestination() {
      Column() {
        Image($r('app.media.app_small_icon'))
          .width(96)
          .height(96)
          .opacity(0.3)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      const currentTime = Date.now();
      if (currentTime - this.exitTime < 2000) {
        (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
      } else {
        this.exitTime = currentTime;
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.common_back_exit') });
      }
      return true;
    })
  }
}
