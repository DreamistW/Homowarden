import { IBestActionSheet } from '@ibestservices/ibest-ui';
import { serverType } from '../common/enums/ServerType';
import { preLogin } from '../common/services/LoginService'

@Entry
@Component
struct Index {
  @State email: string = ''
  @State password: string = ''
  @State isLoading: boolean = false
  @State responseText: string = ''
  @State serverTypeBtnText: string = '请选择';
  serverAddress: string = '';
  serverTypeList: string[] = ["bitwarden.com", "bitwarden.eu", "Custom"];
  serverType: serverType = serverType.NORMAL;

  async handleLogin() {
    if (!this.email || !this.password) {
      return
    }

    if (this.serverType == serverType.CUSTOM && !this.serverAddress) {
      return;
    }

    switch (this.serverType) {
      case serverType.EU:
        this.serverAddress = 'identity.bitwarden.eu';
        break;
      case serverType.CUSTOM:
        break;
      default:
        this.serverAddress = 'identity.bitwarden.com';
    }

    this.isLoading = true
    try {
      const result = await preLogin(`${this.serverAddress}`, this.email);
      this.responseText = result.kdfIterations.toString();
    } catch (error) {
      this.responseText = '登录失败，请重试'
    }
    this.isLoading = false
  }

  build() {
    Column() {
      Text('Homowarden')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .margin({"bottom": 10})
      // 邮箱输入框
      TextInput({
        placeholder: '请输入邮箱',
        text: this.email
      })
        .type(InputType.Email)
        .onChange((value: string) => {
          this.email = value
        })
        .margin(12)

      // 密码输入框
      TextInput({
        placeholder: '请输入密码',
        text: this.password
      })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.password = value
        })
        .margin(12)

      Row() {
        // 服务器选择
        Text('选择服务器')
          .fontSize(16)
          .margin({ right: 8 })
        Button(this.serverTypeBtnText)
          .stateEffect(false)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => {
            IBestActionSheet.show({
              actions: this.serverTypeList,
              onSelect: (position: number) => {
                this.serverType = position as serverType;
                this.serverTypeBtnText = this.serverTypeList[position];
                if(position == serverType.CUSTOM)
                {
                  this.serverAddress = '';
                }
              }
            })
          })
      }


      if (this.serverType == serverType.CUSTOM) {
        Row() {
          Text('https://')
            .fontSize(16)
            .margin({ right: 8 })
          TextInput({ placeholder: '输入域名或IP', text: this.serverAddress })
            .type(InputType.Normal)
            .onChange((value: string) => {
              this.serverAddress = value
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
            this.handleLogin()
          }
        })
        .margin(12)
        .stateEffect(!this.isLoading)

      // 显示响应结果
      Text(this.responseText)
        .fontSize(16)
        .margin(12)
    }
    .width('100%')
    .height('100%')
    .padding(24)
  }
}