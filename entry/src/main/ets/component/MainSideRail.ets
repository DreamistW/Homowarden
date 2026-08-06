import { MainTab } from './MainBottomNavigation';

/** 宽屏主导航，页签语义与手机底部导航保持一致。 */
@Component
export struct MainSideRail {
  @Prop selectedMainTab: MainTab = MainTab.VAULT;
  onSelect: (tab: MainTab) => void = () => {};

  @Builder
  private navigationItem(tab: MainTab, label: Resource, icon: Resource) {
    Row() {
      if (this.selectedMainTab === tab) {
        Divider()
          .vertical(true)
          .width(3)
          .height(40)
          .color($r('app.color.main_nav_selected'))
      }
      Column({ space: 4 }) {
        Image(icon)
          .width(24)
          .height(24)
          .fillColor(this.selectedMainTab === tab ?
            $r('app.color.main_nav_selected') : $r('app.color.main_nav_unselected'))
        Text(label)
          .fontSize(12)
          .fontColor(this.selectedMainTab === tab ?
            $r('app.color.main_nav_selected') : $r('app.color.main_nav_unselected'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .accessibilityGroup(true)
    .accessibilityText(label)
    .onClick(() => this.onSelect(tab))
  }

  build() {
    Column() {
      this.navigationItem(MainTab.VAULT, $r('app.string.nav_vault'), $r('app.media.icon_home'))
      this.navigationItem(MainTab.TOTP, $r('app.string.nav_totp'), $r('app.media.icon_key'))
      this.navigationItem(MainTab.GENERATOR, $r('app.string.nav_generator'), $r('app.media.icon_password'))
      this.navigationItem(MainTab.SHARE, $r('app.string.nav_share'), $r('app.media.icon_share'))
      this.navigationItem(MainTab.SETTINGS, $r('app.string.nav_settings'), $r('app.media.icon_settings'))
    }
    .width(80)
    .height('100%')
    .backgroundColor($r('app.color.main_nav_background'))
  }
}
