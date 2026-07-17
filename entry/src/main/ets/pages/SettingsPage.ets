import { DataPreferences } from '@abner/datastore/src/main/ets/preferences/DataPreferences';
import { EntryRouter } from '../../../../EntryRouter';
import {
  AUTO_LOCK,
  BIOMETRIC_AUTH,
  EMAIL_KEY,
  SERVER_ADDRESS_KEY,
  SERVER_BASE_URL_EU,
  SERVER_BASE_URL_US,
  SERVER_TYPE_KEY,
  ServerType
} from '../utils/Constants';
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { clearAssetAndPreferences, queryAssetSync } from '../utils/AssetUtil';
import { Logger } from '@nzy/logger';
import { IBestDialogUtil, IBestToast } from '@ibestservices/ibest-ui';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { AdaptiveTextButton } from '../component/AdaptiveButton';
import { AntiPeepUtil } from '../utils/AntiPeepUtil';

@Builder
export function SettingsPageBuilder() {
  SettingsPage();
}

@Component
export struct SettingsPage {
  @State autoLockEnabled: boolean = true;
  @State biometricEnabled: boolean = false;
  @State screenCaptureProtectionEnabled: boolean = true;
  @State antiPeepProtectionEnabled: boolean = false;
  @State syncEnabled: boolean = true;
  pathInfos: NavPathStack = new NavPathStack();
  @State versionName: string = '1.0.0';
  @State serverAddressText: string = '';
  email: string = '';

  /** 进入页面时恢复账户、安全开关、服务器和版本展示状态。 */
  aboutToAppear() {
    this.getVersionName();
    this.loadBiometricAuthStatus();
    this.loadAutoLockStatus();
    this.loadScreenCaptureProtectionStatus();
    void this.loadAntiPeepProtectionStatus();
    this.loadServerAddress();
    this.getEmail();
  }

  getEmail() {
    this.email = queryAssetSync(EMAIL_KEY);
  }

  loadAutoLockStatus() {
    try {
      const status = DataPreferences.getInstance().getSync<number>(AUTO_LOCK);
      this.autoLockEnabled = status == 1;
    } catch (err) {
      Logger.error(`Failed to load auto lock status. Error: ${JSON.stringify(err)}`);
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
      Logger.error(`Failed to get version name. Error: ${JSON.stringify(err)}`);
      IBestToast.show(`获取应用版本号失败, 错误信息: ${JSON.stringify(err)}`);
    }
  }

  build() {
    HdsNavDestination() {
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

              Text('开启后, 应用置于后台两分钟会自动锁定密码库')
                .fontSize(12)
                .fontColor('#666666')

              Row() {
                Text('禁止截图和录屏')
                  .fontSize(16)

                Blank()

                Toggle({ type: ToggleType.Switch, isOn: this.screenCaptureProtectionEnabled })
                  .onChange(async (isOn: boolean) => {
                    this.screenCaptureProtectionEnabled = isOn;
                    const applied = await WindowPrivacyUtil.setScreenCaptureProtectionEnabled(isOn);
                    if (!applied) {
                      IBestToast.show('截图录屏保护设置失败');
                    }
                  })
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Text('开启后, 登录态下所有页面会禁止截图和录屏')
                .fontSize(12)
                .fontColor('#666666')

              Row() {
                Text('防窥保护')
                  .fontSize(16)

                Blank()

                Toggle({ type: ToggleType.Switch, isOn: this.antiPeepProtectionEnabled })
                  .onChange(async (isOn: boolean) => {
                    this.antiPeepProtectionEnabled = isOn;
                    if (!isOn) {
                      await AntiPeepUtil.setProtectionEnabled(false);
                      this.antiPeepProtectionEnabled = false;
                      return;
                    }

                    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
                    const enabled = await AntiPeepUtil.setProtectionEnabled(true, context);
                    this.antiPeepProtectionEnabled = enabled;
                    if (!enabled) {
                      IBestToast.show('防窥保护设置失败');
                    }
                  })
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Text('开启后, 检测到窥屏风险时会拉起系统防窥蒙层')
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

              Row() {
                Text('已登录: ')
                  .fontSize(16)

                Blank()

                Text(this.email)
                  .fontSize(16)
                  .fontColor('#666666')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Row() {
                Text('服务器: ')
                  .fontSize(16)

                Blank()

                Text(this.serverAddressText)
                  .fontSize(16)
                  .fontColor('#666666')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding({ top: 4, bottom: 12 })

              Column() {
                AdaptiveTextButton({
                  text: '立即锁定',
                  barWidth: 150,
                  barHeight: 50,
                  fontSize: 18,
                  onButtonClick: () => {
                    this.lockVault();
                  }
                })

                Blank()

                Text('卸载本应用前请务必注销登录, 切记')
                  .fontSize(12)
                  .fontColor('#666666')

                AdaptiveTextButton({
                  text: '注销',
                  barWidth: 150,
                  barHeight: 50,
                  fontSize: 18,
                  onButtonClick: () => {
                    this.logout();
                  }
                })
              }
              .margin({ top: 20 })

              // Button() {
              //   Text('注销')
              //     .fontSize(16)
              //     .fontColor('#FF3B30')
              // }
              // .backgroundColor(Color.Transparent)
              // .width('100%')
              // .height(48)
              // .onClick(() => {
              //   this.logout();
              // })
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
    .titleBar({
      content: {
        title: {
          mainTitle: '设置'
        }
      },
      enableComponentSafeArea: true,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
  }

  clickBeian() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) {
        IBestToast.show('无法打开页面');
        return;
      }
      const want: Want = {
        uri: 'https://beian.miit.gov.cn'
      };
      context.startAbility(want).catch((err: Error) => {
        Logger.error(`Failed to open page. Error: ${err.message}`);
        IBestToast.show(`无法打开页面, 错误信息: ${err.message}`);
      });
    } catch (err) {
      Logger.error(`Failed to open page. Error: ${JSON.stringify(err)}`);
      IBestToast.show(`无法打开页面, 错误信息: ${JSON.stringify(err)}`);
    }
  }

  openEmail() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) {
        IBestToast.show('无法打开邮箱');
        return;
      }
      const want: Want = {
        uri: 'mailto:yume.w@outlook.com'
      };
      context.startAbility(want).catch((err: Error) => {
        Logger.error(`Failed to open email. Error: ${err.message}`);
        IBestToast.show(`无法打开邮箱, 错误信息: ${err.message}`);
      });
    } catch (err) {
      Logger.error(`Failed to open email. Error: ${JSON.stringify(err)}`);
      IBestToast.show(`无法打开邮箱, 错误信息: ${JSON.stringify(err)}`);
    }
  }

  // 加载生物识别状态
  loadBiometricAuthStatus() {
    try {
      const status = DataPreferences.getInstance().getSync<number>(BIOMETRIC_AUTH);
      this.biometricEnabled = status == 1;
    } catch (err) {
      Logger.error(`Failed to load biometric auth status. Error: ${JSON.stringify(err)}`);
      this.biometricEnabled = false;
    }
  }

  // 更新生物识别状态
  updateBiometricAuthStatus(status: boolean) {
    DataPreferences.getInstance().putSync(BIOMETRIC_AUTH, status ? 1 : 0);
  }

  loadScreenCaptureProtectionStatus() {
    this.screenCaptureProtectionEnabled = WindowPrivacyUtil.isScreenCaptureProtectionEnabled();
  }

  async loadAntiPeepProtectionStatus() {
    this.antiPeepProtectionEnabled = await AntiPeepUtil.isProtectionActive();
  }

  loadServerAddress() {
    try {
      const serverType = DataPreferences.getInstance().getSync<ServerType>(SERVER_TYPE_KEY);
      const serverAddress = DataPreferences.getInstance().getSync<string>(SERVER_ADDRESS_KEY);
      this.serverAddressText = this.getServerAddressText(serverType, serverAddress);
    } catch (err) {
      Logger.error(`Failed to load server address. Error: ${JSON.stringify(err)}`);
      this.serverAddressText = SERVER_BASE_URL_US;
    }
  }

  private getServerAddressText(serverType: ServerType, serverAddress: string): string {
    if (serverType === ServerType.EU) {
      return SERVER_BASE_URL_EU;
    }

    if (serverType === ServerType.SELF_HOSTED) {
      const normalizedAddress = this.normalizeSelfHostedAddress(serverAddress);
      return normalizedAddress.length > 0 ? normalizedAddress : '自托管服务器';
    }

    return SERVER_BASE_URL_US;
  }

  private normalizeSelfHostedAddress(serverAddress: string): string {
    let value = serverAddress ? serverAddress.trim() : '';
    value = value.replace(/^https?:\/\//i, '');
    value = value.replace(/\/+$/g, '');
    return value;
  }

  /**
   * 生成随机 challenge 后请求 ATL3 PIN/人脸/指纹认证；仅认证成功才持久化开启状态。
   * 平台异常和失败结果均在回调或当前方法内转换为 UI 状态与提示。
   */
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
        IBestToast.show('生物识别初始化失败');
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
      Logger.info('get userAuth instance success');

      // 订阅认证结果
      userAuthInstance.on('result', {
        onResult: (result) => {
          Logger.info(`userAuthInstance callback result: ${JSON.stringify(result)}`);
          // 取消订阅认证结果
          userAuthInstance.off('result');

          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            // 认证成功，更新状态
            this.biometricEnabled = true;
            this.updateBiometricAuthStatus(true);
            IBestToast.show('生物识别已启用');
          } else {
            // 认证失败，关闭开关
            this.biometricEnabled = false;
            IBestToast.show('认证失败, 生物识别未启用');
          }
        }
      });
      Logger.info('auth on success');
      userAuthInstance.start();
      Logger.info('auth start success');
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to start biometric auth. Error: ${JSON.stringify(err)}`);
      this.biometricEnabled = false;
      IBestToast.show(`生物识别启动失败, 错误信息: ${err.message}`);
    }
  }

  private logout() {
    IBestDialogUtil.open({
      title: '确认',
      message: '确定要注销登录吗?',
      showCancelButton: true,
      onCancel: () => {
        return;
      },
      onConfirm: () => {
        clearAssetAndPreferences();
        void WindowPrivacyUtil.applyForCurrentState();
        // 跳转到登录页面
        this.pathInfos.replacePath({ name: EntryRouter.LoginPage });
      }
    })
  }

  private lockVault() {
    this.pathInfos.replacePath({ name: EntryRouter.UnlockPage });
  }
}
