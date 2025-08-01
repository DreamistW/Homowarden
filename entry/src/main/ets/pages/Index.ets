import { routerInitNavPathStack, routerReturnBuilder, startPage } from '@abner/router';
import { EntryRouter } from '../../../../EntryRouter';
import { createTables } from '../utils/DatabaseUtil';

@Entry
@Component
struct Index {
  private navPathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    routerInitNavPathStack(this.navPathStack);
    createTables();
  }

  @Builder
  routerMap(builderName: string, param: Object) {
    routerReturnBuilder(builderName).builder(param)
  }

  build() {
    Navigation(this.navPathStack) {
      Column() {
        Text('Homowarden')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .margin({ "bottom": 10 })

        Button('登录')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .margin(12)
          .onClick(() => {
            startPage(EntryRouter.LoginPage);
          })
      }
    }.navDestination(this.routerMap)
  }
}