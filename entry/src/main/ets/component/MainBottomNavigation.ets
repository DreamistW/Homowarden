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
  onAdd: () => void = () => {};
  @Prop addEnabled: boolean = false;

  @Builder
  private navigationItem(tab: MainTab, label: string, icon: Resource) {
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
    .width('20%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onSelect(tab);
    })
  }

  @Builder
  private addItem() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(42)
        .height(42)
        .fill(this.addEnabled ? $r('app.color.main_nav_selected') : $r('app.color.main_nav_disabled'))
      Image($r('app.media.icon_add'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.main_nav_add_icon'))
    }
    .width('20%')
    .height(64)
    .enabled(this.addEnabled)
    .onClick(() => {
      if (this.addEnabled) {
        this.onAdd();
      }
    })
  }

  build() {
    Row() {
      this.navigationItem(MainTab.VAULT, '密码库', $r('app.media.icon_home'))
      this.navigationItem(MainTab.TOTP, '验证码', $r('app.media.icon_key'))
      this.addItem()
      this.navigationItem(MainTab.SHARE, '安心分享', $r('app.media.icon_share'))
      this.navigationItem(MainTab.SETTINGS, '设置', $r('app.media.icon_settings'))
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.main_nav_background'))
  }
}
