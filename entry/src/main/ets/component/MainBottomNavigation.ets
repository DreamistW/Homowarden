import { MainNavigationItem, mainNavigationItems, MainTab } from './MainNavigationItems';

/** 展示主页面固定页签并向父组件回传选择结果。 */
@Component
export struct MainBottomNavigation {
  @Prop selectedMainTab: MainTab = MainTab.VAULT;
  onSelect: (tab: MainTab) => void = () => {};

  @Builder
  private navigationItem(tab: MainTab, label: Resource, icon: Resource) {
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
    .accessibilityGroup(true)
    .accessibilityText(label)
    .onClick(() => {
      this.onSelect(tab);
    })
  }

  build() {
    Row() {
      ForEach(mainNavigationItems(), (item: MainNavigationItem) => {
        this.navigationItem(item.tab, item.label, item.icon)
      }, (item: MainNavigationItem) => item.tab.toString())
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.main_nav_background'))
  }
}
