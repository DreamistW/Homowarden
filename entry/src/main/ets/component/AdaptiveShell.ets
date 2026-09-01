/** 宽屏三栏容器，具体列表与详情内容由主页面注入 */
@Component
export struct AdaptiveShell {
  @BuilderParam railBuilder: () => void;
  @BuilderParam listBuilder: () => void;
  @BuilderParam detailBuilder: () => void;

  build() {
    Row() {
      this.railBuilder()
      Divider().vertical(true).width(1).height('100%')
      Column() {
        this.listBuilder()
      }
      .layoutWeight(1)
      .height('100%')
      Divider().vertical(true).width(1).height('100%')
      Column() {
        this.detailBuilder()
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
