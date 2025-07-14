@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('Homowarden')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .margin({ "bottom": 10 })

      Button('登录')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .margin(12)
        .onClick(() => {
          let uiContext: UIContext = this.getUIContext();
          let router = uiContext.getRouter();
          router.pushUrl({ url: 'pages/LoginPage' });
        })
    }
  }
}