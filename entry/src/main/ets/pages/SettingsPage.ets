import { finishPage, replacePage, routerClearPage, RouterPath, setRouterLifeCycle } from '@abner/router';
import { EntryRouter } from '../../../../EntryRouter';

@RouterPath(EntryRouter.SettingsPage)
@Component
export struct SettingsPage {
  @State autoLockEnabled: boolean = true;
  @State biometricEnabled: boolean = false;
  @State syncEnabled: boolean = true;

  aboutToAppear() {
    setRouterLifeCycle({
      onBackPressed: () => {
        finishPage();
        return true;
      }
    })
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Text('←')
            .fontSize(20)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          finishPage();
        })
        
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          // 安全设置
          Column() {
            Text('安全设置')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })

            Row() {
              Text('自动锁定')
                .fontSize(16)
              
              Blank()
              
              Toggle({ type: ToggleType.Switch, isOn: this.autoLockEnabled })
                .onChange((isOn: boolean) => {
                  this.autoLockEnabled = isOn;
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })

            Row() {
              Text('生物识别')
                .fontSize(16)
              
              Blank()
              
              Toggle({ type: ToggleType.Switch, isOn: this.biometricEnabled })
                .onChange((isOn: boolean) => {
                  this.biometricEnabled = isOn;
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }
          .width('100%')
          .padding(16)
          .margin({ bottom: 8 })

          // 同步设置
          Column() {
            Text('同步设置')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })

            Row() {
              Text('自动同步')
                .fontSize(16)
              
              Blank()
              
              Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled })
                .onChange((isOn: boolean) => {
                  this.syncEnabled = isOn;
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }
          .width('100%')
          .padding(16)
          .margin({ bottom: 8 })

          // 账户设置
          Column() {
            Text('账户设置')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })

            Button() {
              Text('更改主密码')
                .fontSize(16)
                .fontColor('#333333')
            }
            .backgroundColor(Color.Transparent)
            .width('100%')
            .height(48)
            .onClick(() => {
              // 跳转到更改主密码页面
            })

            Button() {
              Text('导出密码库')
                .fontSize(16)
                .fontColor('#333333')
            }
            .backgroundColor(Color.Transparent)
            .width('100%')
            .height(48)
            .onClick(() => {
              // 导出密码库
            })

            Button() {
              Text('注销')
                .fontSize(16)
                .fontColor('#FF3B30')
            }
            .backgroundColor(Color.Transparent)
            .width('100%')
            .height(48)
            .onClick(() => {
              this.logout();
            })
          }
          .width('100%')
          .padding(16)
          .margin({ bottom: 8 })

          // 关于
          Column() {
            Text('关于')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })

            Row() {
              Text('版本')
                .fontSize(16)
              
              Blank()
              
              Text('1.0.0')
                .fontSize(16)
                .fontColor('#666666')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }
          .width('100%')
          .padding(16)
          .margin({ bottom: 8 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  private logout() {
    // 清除登录信息
    // 跳转到登录页面
    routerClearPage();
    replacePage(EntryRouter.LoginPage);
  }
} 