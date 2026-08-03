import { AppDialog, AppDialogAction } from '../component/AppDialog';
import { AppToast } from '../utils/AppToast';
import { queryAssetSync } from '../utils/AssetUtil';
import { EMAIL_KEY, SAVE_EMAIL, ServerType } from '../utils/Constants';
import { LoginViewModel } from '../viewmodel/LoginViewModel';
import { EntryRouter } from '../../../../EntryRouter';
import { common } from '@kit.AbilityKit';
import { DataPreferences } from '@abner/datastore';
import { HdsNavDestination } from '@hms.hds.hdsBaseComponent';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { AdaptiveTextButton } from '../component/AdaptiveButton';
import { TwoFactorProvider } from '../model/AccessToken';
import { AppText, AppTextKey } from '../localization/AppText';
import { AppTextResolver } from '../localization/AppTextResolver';
import { VaultViewModel } from '../viewmodel/VaultViewModel';

@Builder
export function LoginPageBuilder() {
  LoginPage();
}

@Component
export struct LoginPage {
  @State viewModel: LoginViewModel = new LoginViewModel();
  @State isLoading: boolean = false;
  @State isNeed2FA: boolean = false;
  @State isNeedNewDevice: boolean = false;
  @State twoFactorInputError: boolean = false;
  @State twoFactorInputHint: ResourceStr = '';
  @State needToSaveEmail: boolean = false;
  @State twoFactorRemember: boolean = false;
  @State pendingEmailLogin: boolean = false;
  private exitTime: number = 0;
  pathInfos: NavPathStack = new NavPathStack();

  aboutToAppear() {
    this.viewModel.loadServerConfig();
    const queryResult = DataPreferences.getInstance().getSync<number>(SAVE_EMAIL);
    if (queryResult && queryResult == 1) {
      this.needToSaveEmail = true;
      this.loadSaveEmail();
    }
  }

  private loadSaveEmail() {
    const email = queryAssetSync(EMAIL_KEY);
    if (email) {
      this.viewModel.email = email;
    }
  }

  @Builder
  twoFactorInputContent() {
    Column({ space: 20 }) {
      Text(this.viewModel.twoFactorProvider === TwoFactorProvider.WEB_AUTHN ? $r('app.string.login_passkey_prompt') : $r('app.string.login_two_factor_prompt'))
        .margin(12)

      if (this.getVisibleTwoFactorProviders().length > 1) {
        Column({ space: 8 }) {
          ForEach(this.getVisibleTwoFactorProviders(), (provider: number) => {
            Button(this.getTwoFactorProviderText(provider))
              .width('100%')
              .stateEffect(provider !== this.viewModel.twoFactorProvider)
              .enabled(provider !== this.viewModel.twoFactorProvider)
              .onClick(() => {
                this.viewModel.setTwoFactorProvider(provider);
                this.twoFactorInputError = false;
                this.updateUI();
              })
          })
        }
      }

      if (this.viewModel.twoFactorProvider !== TwoFactorProvider.WEB_AUTHN) {
        TextInput({ placeholder: $r('app.string.login_enter') })
          .onChange(value => {
            this.viewModel.twoFactorToken = value;
            this.twoFactorInputError = false;
          })
          .type(InputType.Number)
      }

      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.twoFactorRemember })
          .onChange((isOn: boolean) => {
            this.twoFactorRemember = isOn;
            this.viewModel.twoFactorRemember = isOn;
          })
          .accessibilityText($r('app.string.login_remember_me'))
        Text($r('app.string.login_remember_me'))
          .margin(12)
      }

      if (this.twoFactorInputError) {
        Text(this.twoFactorInputHint)
          .width("100%")
          .textAlign(TextAlign.Center)
          .fontColor(Color.Red)
          .fontSize(16)
      }

      if (this.viewModel.twoFactorProvider == TwoFactorProvider.EMAIL) {
        Button($r('app.string.login_send_email_code'))
          .onClick(async () => {
            // 请求未结束前禁用按钮，避免并发发送多个邮箱验证码。
            this.pendingEmailLogin = true;
            const result = await this.viewModel.doSendEmailLogin();
            if (!result) {
              this.twoFactorInputError = true;
              this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
                new AppText(AppTextKey.CODE_SEND_FAILED));
            } else {
              this.twoFactorInputError = true;
              this.twoFactorInputHint = $r('app.string.login_code_sent');
            }
            this.pendingEmailLogin = false;
          })
          .enabled(!this.pendingEmailLogin)
      }
    }.padding(20)
  }

  @Builder
  newDeviceInputContent() {
    Column({ space: 20 }) {
      Text($r('app.string.login_new_device_prompt'))
        .margin(12)
      TextInput({ placeholder: $r('app.string.login_enter') })
        .onChange(value => {
          this.viewModel.twoFactorToken = value;
          this.twoFactorInputError = false;
        })
        .type(InputType.Number)

      if (this.twoFactorInputError) {
        Text(this.twoFactorInputHint)
          .width("100%")
          .textAlign(TextAlign.Center)
          .fontColor(Color.Red)
          .fontSize(16)
      }

      Button($r('app.string.login_send_email_code'))
        .onClick(async () => {
          // 新设备验证码重发与 2FA 邮件发送共享防重入状态。
          this.pendingEmailLogin = true;
          const result = await this.viewModel.doResendNewDeviceOtp();
          if (!result) {
            this.twoFactorInputError = true;
            this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
              new AppText(AppTextKey.CODE_SEND_FAILED));
          } else {
            this.twoFactorInputError = true;
            this.twoFactorInputHint = $r('app.string.login_code_sent');
          }
          this.pendingEmailLogin = false;
        })
        .enabled(!this.pendingEmailLogin)
    }.padding(20)
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 邮箱输入框
        TextInput({
          placeholder: $r('app.string.login_email_placeholder'),
          text: this.viewModel.email
        })
          .type(InputType.Email)
          .onChange((value: string) => {
            this.viewModel.email = value;
            this.viewModel.clearError();
          })
          .margin(12)

        // 记住邮箱的开关，关联viewModel的needSaveEmail
        Row() {
          Text($r('app.string.login_remember_email'))
            .fontSize(16)
            .margin(12)
          Toggle({ type: ToggleType.Switch, isOn: this.needToSaveEmail })
            .onChange((isOn: boolean) => {
              this.needToSaveEmail = isOn;
              this.viewModel.needSaveEmail = isOn;
              DataPreferences.getInstance().putSync(SAVE_EMAIL, isOn ? 1 : 0);
            })
            .accessibilityText($r('app.string.login_remember_email'))
        }

        // 密码输入框
        TextInput({
          placeholder: $r('app.string.login_password_placeholder'),
          text: this.viewModel.password
        })
          .type(InputType.Password)
          .onChange((value: string) => {
            this.viewModel.password = value;
            this.viewModel.clearError();
          })
          .margin(12)

        Row() {
          // 服务器选择
          Text($r('app.string.login_select_server'))
            .fontSize(16)
            .margin({ right: 8 })
          Button(this.getServerTypeButtonText())
            .stateEffect(false)
            .buttonStyle(ButtonStyleMode.TEXTUAL)
             .onClick(() => {
               this.getUIContext().getPromptAction().showActionMenu({
                 buttons: [
                   { text: 'bitwarden.com', color: '#0A59F7' },
                   { text: 'bitwarden.eu', color: '#0A59F7' },
                   { text: this.getSelfHostedServerText(), color: '#0A59F7' }
                 ]
               }).then((result) => {
                   this.viewModel.serverType = this.getServerTypeByIndex(result.index);
                   this.viewModel.clearError();
               }).catch(() => {
                 return;
               });
            })
        }

        if (this.viewModel.serverType == ServerType.SELF_HOSTED) {
          Row() {
            Text('https://')
              .fontSize(16)
              .margin({ right: 8 })
            TextInput({
              placeholder: $r('app.string.login_domain_placeholder'),
              text: this.viewModel.serverAddress
            })
              .type(InputType.Normal)
              .onChange((value: string) => {
                this.viewModel.serverAddress = value;
                this.viewModel.clearError();
              })
              .layoutWeight(1)
          }
          .width('100%')
          .margin(12)
        }

        Column() {
          // 登录按钮
          if (!this.isLoading) {
            AdaptiveTextButton({
              text: this.isLoading ? $r('app.string.login_in_progress') : $r('app.string.login_action'),
              barWidth: 150,
              barHeight: 50,
              fontSize: 18,
              onButtonClick: () => {
                this.handleLogin();
              }
            })
          } else {
            Button($r('app.string.login_in_progress'))
              .margin(14)
              .stateEffect(!this.isLoading)
              .enabled(false)
              .width(150)
              .height(50)
              .borderRadius(75)
          }
        }

        // 显示错误信息
        if (this.viewModel.errorMessage) {
          Text(AppTextResolver.resource(this.viewModel.errorMessage))
            .fontSize(14)
            .fontColor(Color.Red)
            .margin(12)
        }

        // 显示成功信息
        if (this.viewModel.successMessage) {
          Text(AppTextResolver.resource(this.viewModel.successMessage))
            .fontSize(14)
            .fontColor(Color.Green)
            .margin(12)
        }

        // 弹出2FA输入框
        AppDialog({
          visible: $isNeed2FA,
          title: $r('app.string.login_two_factor_title'),
          showCancelButton: true,
          closeOnClickOverlay: false,
          defaultBuilder: (): void => this.twoFactorInputContent(),
          beforeClose: async (action) => {
            if (action === AppDialogAction.CANCEL) {
              return true;
            }
            if (this.viewModel.twoFactorProvider === TwoFactorProvider.WEB_AUTHN) {
              // Passkey 必须先完成系统认证，再继续服务端 2FA 登录流程。
              const context = this.getUIContext().getHostContext() as common.Context;
              const passkeyResult = await this.viewModel.performPasskeyTwoFactor(context);
              if (!passkeyResult) {
                this.twoFactorInputError = true;
                this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
                  new AppText(AppTextKey.PASSKEY_FAILED));
                return false;
              }
            } else {
              const valueLength = this.viewModel.twoFactorToken.trim().length;
              this.twoFactorInputError = !valueLength;
              if (this.twoFactorInputError) {
                this.twoFactorInputHint = $r('app.string.login_error_code_required');
                return false;
              }
            }
            const result = await this.viewModel.continueLogin();
            if (!result) {
              this.twoFactorInputError = true;
              this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
                new AppText(this.viewModel.twoFactorProvider === TwoFactorProvider.WEB_AUTHN ?
                  AppTextKey.PASSKEY_FAILED : AppTextKey.CODE_INVALID));
              return false;
            }
            this.isNeed2FA = false;
            // 异步校验和导航成功后才允许 AppDialog 真正关闭。
            this.updateUI();
            await this.navigateToVault();
            return true;
          }
        })

        // 弹出新设备输入框
        AppDialog({
          visible: $isNeedNewDevice,
          title: $r('app.string.login_new_device_title'),
          showCancelButton: true,
          closeOnClickOverlay: false,
          defaultBuilder: (): void => this.newDeviceInputContent(),
          beforeClose: async (action) => {
            if (action === AppDialogAction.CANCEL) {
              return true;
            }
            const valueLength = this.viewModel.twoFactorToken.trim().length;
            this.twoFactorInputError = !valueLength;
            if (this.twoFactorInputError) {
              this.twoFactorInputHint = $r('app.string.login_error_code_required');
              return false;
            }
            const result = await this.viewModel.continueLogin();
            if (!result) {
              this.twoFactorInputError = true;
              this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
                new AppText(AppTextKey.CODE_INVALID));
              return false;
            }
            this.isNeedNewDevice = false;
            // 保持弹窗直到验证码校验及密码库导航均完成。
            this.updateUI();
            await this.navigateToVault();
            return true;
          }
        })

        // 显示预登录信息（可选）
        // if (this.viewModel.kdfIterations > 0) {
        //   Text(`KDF迭代次数: ${this.viewModel.kdfIterations}`)
        //     .fontSize(12)
        //     .fontColor(Color.Gray)
        //     .margin(12)
        // }
      }
      .width('100%')
      .height('100%')
      .padding(24)
    }
    .titleBar({
      content: {
        title: {
          mainTitle: $r('app.string.login_action')
        }
      },
      enableComponentSafeArea: true
    })
    .hideBackButton(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onBackPressed(() => {
      const currentTime = new Date().getTime();
      if (currentTime - this.exitTime < 2000) {
        (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
      } else {
        this.exitTime = currentTime;
        this.getUIContext().getPromptAction().showToast({
          message: $r('app.string.common_back_exit')
        });
      }
      return true;
    })
  }

  // 处理登录逻辑
  private async handleLogin(): Promise<void> {
    if (this.viewModel.email.length == 0 || this.viewModel.password.length == 0) {
      AppToast.show(this.getUIContext(), $r('app.string.error_validation'));
      return;
    }
    if (this.viewModel.serverType == ServerType.SELF_HOSTED && this.viewModel.serverAddress == undefined) {
      AppToast.show(this.getUIContext(), $r('app.string.error_validation'));
      return;
    }
    this.twoFactorInputError = false;
    this.viewModel.clearError();
    this.isLoading = true;
    this.viewModel.needTwoFactor = false;
    this.viewModel.needNewDevice = false;
    const loginSuccess = await this.viewModel.login();
    if (this.viewModel.needTwoFactor) {
      this.isNeed2FA = this.prepareTwoFactorDialog();
    } else if (this.viewModel.needNewDevice) {
      this.isNeedNewDevice = true;
    } else if (loginSuccess) {
      // 登录成功，跳转到密码库页面
      await this.navigateToVault();
    }
    this.updateUI();
    this.isLoading = false;
    this.getUIContext().getFocusController().clearFocus();
  }

  private prepareTwoFactorDialog(): boolean {
    const visibleProviders = this.getVisibleTwoFactorProviders();
    if (visibleProviders.length === 0) {
      this.viewModel.errorMessage = new AppText(AppTextKey.TWO_FACTOR_UNSUPPORTED);
      this.viewModel.needTwoFactor = false;
      return false;
    }

    if (!visibleProviders.includes(this.viewModel.twoFactorProvider)) {
      this.viewModel.setTwoFactorProvider(visibleProviders[0]);
    }

    return true;
  }

  // 跳转到密码库页面
  private async navigateToVault(): Promise<void> {
    await WindowPrivacyUtil.applyForCurrentState();
    VaultViewModel.beginSession();
    this.pathInfos.replacePath({ name: EntryRouter.VaultPage });
  }

  // 更新UI状态
  private updateUI(): void {
    // 使用clone方法创建新的ViewModel实例来触发UI更新
    this.viewModel = this.viewModel.clone();
  }

  private getTwoFactorProviderText(provider: number): ResourceStr {
    switch (provider) {
      case TwoFactorProvider.WEB_AUTHN:
        return $r('app.string.login_provider_passkey');
      case TwoFactorProvider.EMAIL:
        return $r('app.string.login_provider_email');
      default:
        return $r('app.string.login_provider_authenticator');
    }
  }

  private getVisibleTwoFactorProviders(): number[] {
    // 暂时隐藏通行密钥入口
    return this.viewModel.availableTwoFactorProviders.filter((provider: number) => {
      return provider !== TwoFactorProvider.WEB_AUTHN;
    });
    // return this.viewModel.availableTwoFactorProviders
  }

  // 获取服务器类型按钮文本
  private getServerTypeButtonText(): ResourceStr {
    switch (this.viewModel.serverType) {
      case ServerType.EU:
        return 'bitwarden.eu';
      case ServerType.SELF_HOSTED:
        return $r('app.string.server_self_hosted');
      default:
        return 'bitwarden.com';
    }
  }

  private getSelfHostedServerText(): string {
    return this.getUIContext().getHostContext()?.resourceManager
      .getStringSync($r('app.string.server_self_hosted')) ?? '';
  }

  private getServerTypeByIndex(index: number): ServerType {
    if (index === 1) {
      return ServerType.EU;
    }
    if (index === 2) {
      return ServerType.SELF_HOSTED;
    }
    return ServerType.US;
  }
}
