import { IBestActionSheet } from '@ibestservices/ibest-ui';
import { ServerType } from '../utils/Constants';
import { LoginViewModel } from '../viewmodel/LoginViewModel';

@Entry
@Component
struct LoginPage {
  @State viewModel: LoginViewModel = new LoginViewModel();
  @State isLoading: boolean = false;
  serverTypeList: string[] = ["bitwarden.com", "bitwarden.eu", "Self-hosted"];

  build() {
    Column() {
      Text('登录')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .margin({"bottom": 10})
      
      // 邮箱输入框
      TextInput({
        placeholder: '请输入邮箱',
        text: this.viewModel.email
      })
        .type(InputType.Email)
        .onChange((value: string) => {
          this.viewModel.email = value;
          this.viewModel.clearError();
          this.updateUI();
        })
        .margin(12)

      // 密码输入框
      TextInput({
        placeholder: '请输入密码',
        text: this.viewModel.password
      })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.viewModel.password = value;
          this.viewModel.clearError();
          this.updateUI();
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
                if (position == ServerType.SELF_HOSTED) {
                  this.viewModel.serverAddress = '';
                }
                this.updateUI();
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
              this.updateUI();
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

      // 显示调试信息（可选）
      if (this.viewModel.kdfIterations > 0) {
        Text(`KDF迭代次数: ${this.viewModel.kdfIterations}`)
          .fontSize(12)
          .fontColor(Color.Gray)
          .margin(12)
      }
    }
    .width('100%')
    .height('100%')
    .padding(24)
  }

  // 处理登录逻辑
  private async handleLogin(): Promise<void> {
    this.isLoading = true;
    await this.viewModel.login();
    this.updateUI();
    this.isLoading = false;
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