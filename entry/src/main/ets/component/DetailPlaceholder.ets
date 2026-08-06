@Builder
export function DetailPlaceholderBuilder() {
  DetailPlaceholder();
}

/** 分栏未选择内容时仅展示弱化的应用图标。 */
@Component
export struct DetailPlaceholder {
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
    .onBackPressed(() => true)
  }
}
