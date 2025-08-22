import { IBestRadio, IBestRadioGroup, IBestToast } from '@ibestservices/ibest-ui';
import { CipherItemType } from '../utils/Constants';
import { AddCipherViewModel } from '../viewmodel/AddCipherViewModel';

@Builder
export function AddCipherPageBuilder() {
  AddCipherPage();
}

@Component
export struct AddCipherPage {
  @State viewModel: AddCipherViewModel = new AddCipherViewModel();
  @State cipherType: CipherItemType = CipherItemType.LOGIN;
  @State isSubmitting: boolean = false;
  allowSave: boolean = false;
  pathInfos: NavPathStack = new NavPathStack();
  ConfirmBtn: NavigationMenuItem = {
    'value': '',
    'icon': 'resources/base/media/icon_confirm.svg',
    isEnabled: true,
    'action': () => {
      this.saveCipher();
    }
  }
  group: string = 'itemTypeSelector';

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          Column() {
            Text('类型')
              .fontSize(14)
              .margin(8)

            IBestRadioGroup({
              group: this.group,
              active: $cipherType,
              placeDirection: Axis.Horizontal,
              space: 12
            }) {
              IBestRadio({
                group: this.group,
                label: '登录',
                name: CipherItemType.LOGIN,
                labelDisabled: true
              })
              IBestRadio({
                group: this.group,
                label: '安全笔记',
                name: CipherItemType.NOTE,
                labelDisabled: true
              })
            }

            Text().margin(8)

            IBestRadioGroup({ group: this.group, active: $cipherType, placeDirection: Axis.Horizontal }) {
              IBestRadio({
                group: this.group,
                label: '卡片',
                name: CipherItemType.CARD,
                labelDisabled: true
              })
              IBestRadio({
                group: this.group,
                label: '身份信息',
                name: CipherItemType.IDENTITY,
                labelDisabled: true
              })
            }
          }

          // 名称
          Text('名称')
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 12,
              bottom: 4
            })
          TextInput()
            .onChange((v: string) => {
              this.viewModel.name = v;
              this.canSave();
            })
            .margin({ left: 16, right: 16 })

          // 用户名
          Text('用户名')
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 12,
              bottom: 4
            })
          TextInput()
            .onChange((v: string) => {
              this.viewModel.loginItem.username = v;
            })
            .margin({ left: 16, right: 16 })

          // 密码
          Text('密码')
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 12,
              bottom: 4
            })
          TextInput({ placeholder: '输入密码' })
            .type(InputType.Password)
            .onChange((v: string) => {
              this.viewModel.loginItem.password = v;
            })
            .margin({ left: 16, right: 16 })

          // 网站
          Text('网站')
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 12,
              bottom: 4
            })
          TextInput({ placeholder: '例如：https://example.com' })
            .onChange((v: string) => {
              this.viewModel.loginUri.uri = v;
            })
            .margin({ left: 16, right: 16 })

          // 备注
          Text('备注')
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 12,
              bottom: 4
            })
          TextInput({ placeholder: '可选', text: this.viewModel.notes })
            .onChange((v: string) => {
              this.viewModel.notes = v;
            })
            .margin({ left: 16, right: 16, bottom: 24 })

          // 错误提示
          if (this.viewModel.errorMessage && this.viewModel.errorMessage.length > 0) {
            Text(this.viewModel.errorMessage)
              .fontColor(Color.Red)
              .fontSize(14)
              .margin({ left: 16, right: 16, bottom: 16 })
          }
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
    }
    .title('添加项目')
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
      const param = ctx.pathInfo.param as string;
      if (param) {
        this.viewModel.symmetricKey = param;
      }
    })
    .menus([this.ConfirmBtn])
  }

  private canSave() {
    this.allowSave = this.viewModel.canSave();
  }

  private async saveCipher() {
    if (!this.allowSave) {
      IBestToast.show('请先输入名称');
      return;
    }
    this.isSubmitting = true;
    const ok = await this.viewModel.submitCreate();
    this.isSubmitting = false;
    if (ok) {
      this.pathInfos.pop();
    }
  }
} 