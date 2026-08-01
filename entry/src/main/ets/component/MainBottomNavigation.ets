export enum MainTab {
  VAULT = 0,
  TOTP = 1,
  SHARE = 2,
  SETTINGS = 3
}

@Component
export struct MainBottomNavigation {
  @Prop selectedMainTab: MainTab = MainTab.VAULT;
  onSelect: (tab: MainTab) => void = () => {};

  @Builder
  private navigationItem(tab: MainTab, label: ResourceStr, icon: Resource) {
    Column({ space: 3 }) {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.selectedMainTab === tab ?
          $r('app.color.main_nav_selected') : $r('app.color.main_nav_unselected'))
      Text(label)
        .fontSize(11)
        .fontColor(this.selectedMainTab === tab ?
          $r('app.color.main_nav_selected') : $r('app.color.main_nav_unselected'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('25%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onSelect(tab);
    })
  }

  build() {
    Row() {
      this.navigationItem(MainTab.VAULT, $r('app.string.nav_vault'), $r('app.media.icon_home'))
      this.navigationItem(MainTab.TOTP, $r('app.string.nav_totp'), $r('app.media.icon_key'))
      this.navigationItem(MainTab.SHARE, $r('app.string.nav_share'), $r('app.media.icon_share'))
      this.navigationItem(MainTab.SETTINGS, $r('app.string.nav_settings'), $r('app.media.icon_settings'))
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.main_nav_background'))
  }
}
