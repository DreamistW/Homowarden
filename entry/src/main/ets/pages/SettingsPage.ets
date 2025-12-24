import { DataPreferences } from '@abner/datastore/src/main/ets/preferences/DataPreferences';
import { EntryRouter } from '../../../../EntryRouter';
import {
  ACCESS_TOKEN_KEY_1,
  ACCESS_TOKEN_KEY_2,
  AUTO_LOCK, BACKGROUND_TIMESTAMP, BIOMETRIC_AUTH,
  KDF_PARAM_KEY,
  LOGIN_STATUS_KEY, MASTER_KEY,
  PRIVATE_KEY_1,
  PRIVATE_KEY_2,
  REFRESH_TOKEN_KEY,
  TOKEN_EXPIRE_TIME_KEY,
  TWO_FACTOR_TOKEN_KEY,
  USER_KEY} from '../utils/Constants';
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { deleteAsset } from '../utils/AssetUtil';

@Builder
export function SettingsPageBuilder() {
  SettingsPage();
}

@Component
export struct SettingsPage {
  @State autoLockEnabled: boolean = true;
  @State biometricEnabled: boolean = false;
  @State syncEnabled: boolean = true;
  pathInfos: NavPathStack = new NavPathStack();
  @State versionName: string = '1.0.0';

  aboutToAppear() {
    this.getVersionName();
    this.loadBiometricAuthStatus();
    this.loadAutoLockStatus();
  }

  loadAutoLockStatus() {
    try {
      const status = DataPreferences.getInstance().getSync<number>(AUTO_LOCK);
      this.autoLockEnabled = status == 1;
    } catch (err) {
      console.error(`Failed to load auto lock status. Error: ${JSON.stringify(err)}`);
      this.autoLockEnabled = false;
    }
  }

  // 获取应用版本号
  async getVersionName() {
    try {
      const bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleFlags);
      if (bundleInfo && bundleInfo.versionName) {
        this.versionName = bundleInfo.versionName;
      }
    } catch (err) {
      console.error(`Failed to get version name. Error: ${JSON.stringify(err)}`);
    }
  }

  build() {
    NavDestination() {
      Column() {
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
                    DataPreferences.getInstance().putSync(AUTO_LOCK, isOn ? 1 : 0);
                  })
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Text('开启后, 应用置于后台两分钟后会自动锁定')
                .fontSize(12)
                .fontColor('#666666')

              Row() {
                Text('生物识别')
                  .fontSize(16)

                Blank()

                Toggle({ type: ToggleType.Switch, isOn: this.biometricEnabled })
                  .onChange((isOn: boolean) => {
                    if (isOn) {
                      this.biometricEnabled = true;
                      // 打开开关时，先发起生物识别认证
                      this.startBiometricAuth();
                    } else {
                      // 关闭开关时，直接更新状态
                      this.biometricEnabled = false;
                      this.updateBiometricAuthStatus(false);
                    }
                  })
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Text('开启后, 可以使用锁屏密码/指纹/人脸解锁密码库')
                .fontSize(12)
                .fontColor('#666666')
            }
            .width('100%')
            .padding(16)
            .margin({ bottom: 8 })

            // 同步设置
            // Column() {
            //   Text('同步设置')
            //     .fontSize(16)
            //     .fontWeight(FontWeight.Medium)
            //     .margin({ bottom: 12 })
            //
            //   Row() {
            //     Text('自动同步')
            //       .fontSize(16)
            //
            //     Blank()
            //
            //     Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled })
            //       .onChange((isOn: boolean) => {
            //         this.syncEnabled = isOn;
            //       })
            //   }
            //   .width('100%')
            //   .padding({ top: 12, bottom: 12 })
            // }
            // .width('100%')
            // .padding(16)
            // .margin({ bottom: 8 })

            // 账户设置
            Column() {
              Text('账户设置')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })

              // Button() {
              //   Text('更改主密码')
              //     .fontSize(16)
              //     .fontColor('#333333')
              // }
              // .backgroundColor(Color.Transparent)
              // .width('100%')
              // .height(48)
              // .onClick(() => {
              //   // 跳转到更改主密码页面
              // })
              //
              // Button() {
              //   Text('导出密码库')
              //     .fontSize(16)
              //     .fontColor('#333333')
              // }
              // .backgroundColor(Color.Transparent)
              // .width('100%')
              // .height(48)
              // .onClick(() => {
              //   // 导出密码库
              // })

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

                Text(this.versionName)
                  .fontSize(16)
                  .fontColor('#666666')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Row() {
                Text('作者邮箱')
                  .fontSize(16)

                Blank()

                Text('yume.w@outlook.com')
                  .fontSize(16)
                  .fontColor('#007DFF')
                  .decoration({ type: TextDecorationType.Underline })
                  .onClick(() => {
                    this.openEmail();
                  })
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
        .align(Alignment.TopStart)
      }
      .width('100%')
      .height('100%')
    }
    .title('设置')
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onActive(() => {
      const autoLockStatus = DataPreferences.getInstance().getSync<number>(AUTO_LOCK);
      if (autoLockStatus == 1) {
        const currentTime = Math.floor(Date.now() / 1000);
        const backgroundTime = DataPreferences.getInstance().getSync<number>(BACKGROUND_TIMESTAMP);
        if (currentTime - backgroundTime > 120) {
          this.pathInfos.pushPath({ name: EntryRouter.BiometricAuthPage });
        }
      }
    })
    .onHidden(() => {
      DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
    })
  }

  openEmail() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) {
        this.getUIContext().getPromptAction().showToast({
          message: '无法打开邮箱'
        });
        return;
      }
      const want: Want = {
        uri: 'mailto:yume.w@outlook.com'
      };
      context.startAbility(want).catch((err: Error) => {
        console.error(`Failed to open email. Error: ${err.message}`);
        this.getUIContext().getPromptAction().showToast({
          message: '无法打开邮箱'
        });
      });
    } catch (err) {
      console.error(`Failed to open email. Error: ${JSON.stringify(err)}`);
      this.getUIContext().getPromptAction().showToast({
        message: '无法打开邮箱'
      });
    }
  }

  // 加载生物识别状态
  loadBiometricAuthStatus() {
    try {
      const status = DataPreferences.getInstance().getSync<number>(BIOMETRIC_AUTH);
      this.biometricEnabled = status == 1;
    } catch (err) {
      console.error(`Failed to load biometric auth status. Error: ${JSON.stringify(err)}`);
      this.biometricEnabled = false;
    }
  }

  // 更新生物识别状态
  updateBiometricAuthStatus(status: boolean) {
    DataPreferences.getInstance().putSync(BIOMETRIC_AUTH, status ? 1 : 0);
  }

  // 发起生物识别认证
  startBiometricAuth() {
    try {
      const rand = cryptoFramework.createRandom();
      const len: number = 16; // Generate a 16-byte random number.
      let randData: Uint8Array | null = null;
      let retryCount = 0;
      while (retryCount < 3) {
        randData = rand?.generateRandomSync(len)?.data;
        if (randData) {
          break;
        }
        retryCount++;
      }
      if (!randData) {
        this.getUIContext().getPromptAction().showToast({
          message: '生物识别初始化失败'
        });
        this.biometricEnabled = false;
        return;
      }

      // 设置认证参数
      const authParam: userAuth.AuthParam = {
        challenge: randData,
        authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
      };

      // 配置认证界面
      const widgetParam: userAuth.WidgetParam = {
        title: '请进行身份认证',
      };

      // 获取认证对象
      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      console.info('get userAuth instance success');

      // 订阅认证结果
      userAuthInstance.on('result', {
        onResult: (result) => {
          console.info(`userAuthInstance callback result: ${JSON.stringify(result)}`);
          // 取消订阅认证结果
          userAuthInstance.off('result');

          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            // 认证成功，更新状态
            this.biometricEnabled = true;
            this.updateBiometricAuthStatus(true);
            this.getUIContext().getPromptAction().showToast({
              message: '生物识别已启用'
            });
          } else {
            // 认证失败，关闭开关
            this.biometricEnabled = false;
            this.getUIContext().getPromptAction().showToast({
              message: '认证失败，生物识别未启用'
            });
          }
        }
      });
      console.info('auth on success');
      userAuthInstance.start();
      console.info('auth start success');
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to start biometric auth. Error: ${JSON.stringify(err)}`);
      this.biometricEnabled = false;
      this.getUIContext().getPromptAction().showToast({
        message: '生物识别启动失败'
      });
    }
  }

  private logout() {
    // 清除登录信息
    DataPreferences.getInstance().put(LOGIN_STATUS_KEY, 0);
    // 删除原本的凭据
    deleteAsset(MASTER_KEY);
    deleteAsset(ACCESS_TOKEN_KEY_1);
    deleteAsset(ACCESS_TOKEN_KEY_2);
    deleteAsset(REFRESH_TOKEN_KEY);
    deleteAsset(TOKEN_EXPIRE_TIME_KEY);
    deleteAsset(PRIVATE_KEY_1);
    deleteAsset(PRIVATE_KEY_2);
    deleteAsset(USER_KEY);
    deleteAsset(KDF_PARAM_KEY);
    deleteAsset(TWO_FACTOR_TOKEN_KEY);
    // 跳转到登录页面
    this.pathInfos.replacePath({ name: EntryRouter.LoginPage });
  }
} 