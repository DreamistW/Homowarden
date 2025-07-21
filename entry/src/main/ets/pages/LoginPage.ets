import { IBestActionSheet, IBestDialog, IBestSwitch } from '@ibestservices/ibest-ui';
import { queryAssetSync } from '../utils/Asset';
import { EMAIL_KEY, ServerType } from '../utils/Constants';
import { LoginViewModel } from '../viewmodel/LoginViewModel';

@Entry
@Component
struct LoginPage {
  @State viewModel: LoginViewModel = new LoginViewModel();
  @State isLoading: boolean = false;
  @State isNeed2FA: boolean = false;
  @State twoFactorInputError: boolean = false;
  @State twoFactorInputHint: string = '';
  @State needToSaveEmail: boolean = false;
  serverTypeList: string[] = ["bitwarden.com", "bitwarden.eu", "Self-hosted"];

  aboutToAppear() {
    this.loadSaveEmail();
    this.viewModel.loadServerConfig();
  }

  private loadSaveEmail() {
    const email = queryAssetSync(EMAIL_KEY);
    if (email) {
      this.viewModel.email = email;
      this.needToSaveEmail = true;
      this.viewModel.needSaveEmail = true;
    }
  }

  @Builder
  twoFactorInputContain() {
    Column({ space: 20 }) {
      Text('请输入身份验证器的两步验证码')
        .margin(12)
      TextInput({ placeholder: '请输入' })
        .onChange(value => {
          this.viewModel.twoFactorToken = value;
          this.twoFactorInputError = false;
        })
      if (this.twoFactorInputError) {
        Text(this.twoFactorInputHint)
          .width("100%")
          .textAlign(TextAlign.Center)
          .fontColor(Color.Red)
          .fontSize(16)
      }
    }.padding(20)
  }

  build() {
    Column() {
      Text('登录')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .margin({ "bottom": 10 })

      // 邮箱输入框
      TextInput({
        placeholder: '请输入邮箱',
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
        Text('记住邮箱')
          .fontSize(16)
          .margin(12)
        IBestSwitch({
          value: $needToSaveEmail,
          onChange: () => {
            this.viewModel.needSaveEmail = this.needToSaveEmail;
          }
        })
      }

      // 密码输入框
      TextInput({
        placeholder: '请输入密码',
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
        Text('选择服务器')
          .fontSize(16)
          .margin({ right: 8 })
        Button(this.getServerTypeButtonText())
          .stateEffect(false)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => {
            IBestActionSheet.show({
              actions: this.serverTypeList,
              onSelect: (position: number) => {
                this.viewModel.serverType = position as ServerType;
                this.viewModel.clearError();
              }
            })
          })
      }

      if (this.viewModel.serverType == ServerType.SELF_HOSTED) {
        Row() {
          Text('https://')
            .fontSize(16)
            .margin({ right: 8 })
          TextInput({
            placeholder: '输入域名或IP',
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

      // 登录按钮
      Button(this.isLoading ? '登录中...' : '登录')
        .onClick(() => {
          if (!this.isLoading) {
            this.handleLogin();
          }
        })
        .margin(12)
        .stateEffect(!this.isLoading)
        .enabled(!this.isLoading)

      // 显示错误信息
      if (this.viewModel.errorMessage) {
        Text(this.viewModel.errorMessage)
          .fontSize(14)
          .fontColor(Color.Red)
          .margin(12)
      }

      // 显示成功信息
      if (this.viewModel.successMessage) {
        Text(this.viewModel.successMessage)
          .fontSize(14)
          .fontColor(Color.Green)
          .margin(12)
      }

      // 弹出2FA输入框
      IBestDialog({
        visible: this.isNeed2FA,
        title: '两步验证',
        showCancelButton: true,
        closeOnClickOverlay: false,
        defaultBuilder: (): void => this.twoFactorInputContain(),
        beforeClose: async (action) => {
          if (action === 'cancel') {
            return true;
          }
          const valueLength = this.viewModel.twoFactorToken.trim().length;
          this.twoFactorInputError = !valueLength;
          if (this.twoFactorInputError) {
            this.twoFactorInputHint = '验证码不能为空';
            return false;
          }
          const result = await this.viewModel.login();
          if (!result) {
            this.twoFactorInputError = true;
            this.twoFactorInputHint = '无效的验证码';
            return false;
          }
          this.isNeed2FA = false;
          this.updateUI();
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

  // 处理登录逻辑
  private async handleLogin(): Promise<void> {
    this.twoFactorInputError = false;
    this.viewModel.clearError();
    this.isLoading = true;
    await this.viewModel.login();
    if (this.viewModel.needTwoFactor) {
      this.isNeed2FA = true;
    }
    this.updateUI();
    this.isLoading = false;
    this.getUIContext().getFocusController().clearFocus();
  }

  // 更新UI状态
  private updateUI(): void {
    // 使用clone方法创建新的ViewModel实例来触发UI更新
    this.viewModel = this.viewModel.clone();
  }

  // 获取服务器类型按钮文本
  private getServerTypeButtonText(): string {
    switch (this.viewModel.serverType) {
      case ServerType.EU:
        return 'bitwarden.eu';
      case ServerType.SELF_HOSTED:
        return 'Self-hosted';
      default:
        return 'bitwarden.com';
    }
  }
}