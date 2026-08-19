import { DataPreferences } from '@abner/datastore/src/main/ets/preferences/DataPreferences';
import {
  AutoLockTimeout,
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
import { AppToast } from '../utils/AppToast';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { AdaptiveTextButton } from '../component/AdaptiveButton';
import { ConfirmDialog } from '../component/ConfirmDialog';
import { AntiPeepUtil } from '../utils/AntiPeepUtil';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { GENERATOR_HISTORY_TABLE, GeneratorDatabaseUtil } from '../utils/GeneratorDatabaseUtil';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { AppDropdown } from '../component/AppDropdown';
import { AppOptionFactory } from '../localization/AppOptionFactory';
import { AutoLockUtil } from '../utils/AutoLockUtil';

@Component
export struct SettingsPage {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  @Prop @Watch('handleActiveChanged') isActive: boolean = false;
  @State autoLockTimeoutSeconds: number = AutoLockTimeout.NEVER;
  @State biometricEnabled: boolean = false;
  @State screenCaptureProtectionEnabled: boolean = true;
  @State antiPeepProtectionEnabled: boolean = false;
  @State syncEnabled: boolean = true;
  onLockVault: () => void = () => {};
  onLogout: () => void = () => {};
  @State versionName: string = '1.0.0';
  @State serverAddressText: string = '';
  email: string = '';
  @State confirmTitle: ResourceStr = '';
  @State confirmMessage: ResourceStr = '';
  @State confirmText: ResourceStr = $r('app.string.common_confirm');
  private confirmAction: () => Promise<boolean> = async () => true;
  private confirmController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: $confirmTitle,
      message: $confirmMessage,
      confirmText: $confirmText,
      onConfirm: async (): Promise<boolean> => {
        return await this.confirmAction();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  private showConfirm(title: ResourceStr, message: ResourceStr, action: () => void): void {
    this.confirmTitle = title;
    this.confirmMessage = message;
    this.confirmAction = async (): Promise<boolean> => {
      action();
      return true;
    };
    this.confirmController.open();
  }

  aboutToAppear(): void {
    this.refreshSettings();
  }

  private handleActiveChanged(): void {
    if (this.isActive) {
      // Tabs 页面重新激活时不会重建组件，需要主动同步可能由其他页面修改的设置。
      this.refreshSettings();
    }
  }

  private refreshSettings(): void {
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
    this.autoLockTimeoutSeconds = AutoLockUtil.getTimeoutSeconds();
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
      AppToast.show(this.getUIContext(), $r('app.string.error_unknown'));
    }
  }

  build() {
    Column() {
        Scroll() {
          Column() {
            // 安全设置
            Column() {
              Text($r('app.string.settings_security'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })

              Row() {
                Text($r('app.string.settings_biometrics'))
                  .fontSize(16)

                Blank()

                Toggle({ type: ToggleType.Switch, isOn: this.biometricEnabled })
                  .accessibilityText($r('app.string.settings_biometrics'))
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
              .padding({ top: 20, bottom: 4 })

              Text($r('app.string.settings_biometrics_desc'))
                .fontSize(12)
                .fontColor('#666666')
                .alignSelf(ItemAlign.Start)

              Row() {
                Text($r('app.string.settings_auto_lock'))
                  .fontSize(16)

                Blank()

                Column() {
                  AppDropdown({
                    options: AppOptionFactory.autoLockTimeouts(),
                    value: this.autoLockTimeoutSeconds,
                    accessibilityLabel: $r('app.string.settings_auto_lock'),
                    onChange: (value: number) => {
                      this.autoLockTimeoutSeconds = AutoLockUtil.setTimeoutSeconds(value);
                    }
                  })
                }
                .width(140)
              }
              .width('100%')
              .padding({ top: 20, bottom: 4 })

              Text($r('app.string.settings_auto_lock_desc'))
                .fontSize(12)
                .fontColor('#666666')
                .alignSelf(ItemAlign.Start)

              Row() {
                Text($r('app.string.settings_block_capture'))
                  .fontSize(16)

                Blank()

                Toggle({ type: ToggleType.Switch, isOn: this.screenCaptureProtectionEnabled })
                  .accessibilityText($r('app.string.settings_block_capture'))
                  .onChange(async (isOn: boolean) => {
                    this.screenCaptureProtectionEnabled = isOn;
                    // 先保存用户选择并尝试应用窗口属性；系统调用失败时提示用户，开关状态不回滚。
                    const applied = await WindowPrivacyUtil.setScreenCaptureProtectionEnabled(isOn);
                    if (!applied) {
                      AppToast.show(this.getUIContext(), $r('app.string.error_save_failed'));
                    }
                  })
              }
              .width('100%')
              .padding({ top: 20, bottom: 4 })

              Text($r('app.string.settings_block_capture_desc'))
                .fontSize(12)
                .fontColor('#666666')
                .alignSelf(ItemAlign.Start)

              Row() {
                Text($r('app.string.settings_anti_peep'))
                  .fontSize(16)

                Blank()

                Toggle({ type: ToggleType.Switch, isOn: this.antiPeepProtectionEnabled })
                  .accessibilityText($r('app.string.settings_anti_peep'))
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
                      AppToast.show(this.getUIContext(), $r('app.string.error_save_failed'));
                    }
                  })
              }
              .width('100%')
              .padding({ top: 20, bottom: 4 })

              Text($r('app.string.settings_anti_peep_desc'))
                .fontSize(12)
                .fontColor('#666666')
                .alignSelf(ItemAlign.Start)
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
              Text($r('app.string.settings_account'))
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
                Text($r('app.string.settings_logged_in_as'))
                  .fontSize(16)

                Blank()

                Text(this.email)
                  .fontSize(16)
                  .fontColor('#666666')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Row() {
                Text($r('app.string.settings_server'))
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
                  text: $r('app.string.common_lock_now'),
                  barWidth: 150,
                  barHeight: 50,
                  fontSize: 18,
                  onButtonClick: () => {
                    this.lockVault();
                  }
                })

                Blank()

                Text($r('app.string.settings_logout_warning'))
                  .fontSize(12)
                  .fontColor('#666666')

                AdaptiveTextButton({
                  text: $r('app.string.unlock_logout'),
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
              Text($r('app.string.settings_about'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })

              Row() {
                Text($r('app.string.common_version'))
                  .fontSize(16)

                Blank()

                Text(this.versionName)
                  .fontSize(16)
                  .fontColor('#666666')
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })

              Row() {
                Text($r('app.string.settings_author_email'))
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

              Row() {
                Text($r('app.string.settings_registration'))
                  .fontSize(16)

                Blank()

                Text($r('app.string.settings_registration_value'))
                  .fontSize(16)
                  .fontColor('#007DFF')
                  .decoration({ type: TextDecorationType.Underline })
                  .onClick(() => {
                    this.clickBeian();
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

  clickBeian() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) {
        AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
        return;
      }
      const want: Want = {
        uri: 'https://beian.miit.gov.cn'
      };
      context.startAbility(want).catch((err: Error) => {
        Logger.error(`Failed to open page. Error: ${err.message}`);
        AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
      });
    } catch (err) {
      Logger.error(`Failed to open page. Error: ${JSON.stringify(err)}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
    }
  }

  openEmail() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) {
        AppToast.show(this.getUIContext(), $r('app.string.error_unknown'));
        return;
      }
      const want: Want = {
        uri: 'mailto:yume.w@outlook.com'
      };
      context.startAbility(want).catch((err: Error) => {
        Logger.error(`Failed to open email. Error: ${err.message}`);
        AppToast.show(this.getUIContext(), $r('app.string.error_unknown'));
      });
    } catch (err) {
      Logger.error(`Failed to open email. Error: ${JSON.stringify(err)}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_unknown'));
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

  private handleLocaleRevision(): void {
    this.loadServerAddress();
  }

  private getServerAddressText(serverType: ServerType, serverAddress: string): string {
    if (serverType === ServerType.EU) {
      return SERVER_BASE_URL_EU;
    }

    if (serverType === ServerType.SELF_HOSTED) {
      const normalizedAddress = this.normalizeSelfHostedAddress(serverAddress);
      return normalizedAddress.length > 0 ? normalizedAddress :
        (this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.server_self_hosted')) ?? '');
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
   * 先完成一次系统认证，再持久化生物识别开关，防止未授权启用。
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
        AppToast.show(this.getUIContext(), $r('app.string.unlock_biometric_start_failed'));
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
      const authTitle: string = this.getUIContext().getHostContext()?.resourceManager
        .getStringSync($r('app.string.unlock_auth_title')) ?? '';
      const widgetParam: userAuth.WidgetParam = {
        title: authTitle,
      };

      // 获取认证对象
      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      Logger.info('get userAuth instance success');

      // 订阅认证结果
      userAuthInstance.on('result', {
        onResult: (result) => {
          Logger.info(`userAuthInstance callback result: ${JSON.stringify(result)}`);
          // 结果监听为一次性订阅，及时解除可避免后续认证重复回调当前页面。
          userAuthInstance.off('result');

          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            // 认证成功，更新状态
            this.biometricEnabled = true;
            this.updateBiometricAuthStatus(true);
            AppToast.show(this.getUIContext(), $r('app.string.common_success'));
          } else {
            // 认证失败，关闭开关
            this.biometricEnabled = false;
            AppToast.show(this.getUIContext(), $r('app.string.unlock_biometric_failed'));
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
      AppToast.show(this.getUIContext(), $r('app.string.unlock_biometric_start_failed'));
    }
  }

  private logout() {
    this.showConfirm($r('app.string.common_confirm'), $r('app.string.settings_logout_confirm'), () => {
      void this.performLogout();
    });
  }

  private async performLogout(): Promise<void> {
    const cleanupErrors: string[] = [];
    try {
      await VaultViewModel.prepareForLogout();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to prepare vault for logout: ${error}`);
    }
    try {
      await GeneratorDatabaseUtil.getInstance().deleteAllData(GENERATOR_HISTORY_TABLE);
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to clear generator history during logout: ${error}`);
    }
    try {
      await DatabaseUtil.getInstance().clearVaultData();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to clear vault database during logout: ${error}`);
    }
    try {
      clearAssetAndPreferences();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to clear credentials during logout: ${error}`);
    }
    try {
      await WindowPrivacyUtil.applyForCurrentState();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to update window privacy during logout: ${error}`);
    }
    this.onLogout();
    if (cleanupErrors.length > 0) {
      Logger.error(`Logout completed with cleanup errors: ${cleanupErrors.join('; ')}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_storage'));
    }
  }

  private lockVault() {
    this.onLockVault();
  }
}
