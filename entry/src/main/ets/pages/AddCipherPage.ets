import { EntryRouter } from '../../../../EntryRouter';
import { CipherItemType } from '../utils/Constants';

@Builder
export function AddCipherPageBuilder() {
  AddCipherPage();
}

@Component
export struct AddCipherPage {
  @State cipherType: number = 1; // 1=登录, 2=安全笔记, 3=卡片, 4=身份信息
  @State name: string = '';
  @State username: string = '';
  @State password: string = '';
  @State url: string = '';
  @State notes: string = '';
  @State isSubmitting: boolean = false;
  pathInfos: NavPathStack = new NavPathStack();
  EditItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_confirm.svg', 'action': () => {
      this.saveCipher();
    }
  }

  build() {
    NavDestination(){
      Column() {
        Scroll() {
          Column() {
            // 类型选择
            Column() {
              Text('类型')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })

              Row() {
                ForEach([CipherItemType.LOGIN, CipherItemType.NOTE, CipherItemType.CARD, CipherItemType.IDENTITY], (type: CipherItemType) => {
                  Button() {
                    Text(this.getTypeName(type))
                      .fontSize(14)
                      .fontColor(this.cipherType === type ? Color.White : '#333333')
                  }
                  .width('22%')
                  .height(40)
                  .borderRadius(8)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.cipherType = type;
                  })
                })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .margin({ bottom: 8 })

            // 基本信息
            Column() {
              Text('基本信息')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })

              TextInput({
                placeholder: '名称',
                text: this.name
              })
                .width('100%')
                .height(48)
                .borderRadius(8)
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => {
                  this.name = value;
                })
                .margin({ bottom: 12 })
            }
            .width('100%')
            .padding(16)
            .margin({ bottom: 8 })

            // 登录信息（仅登录类型显示）
            if (this.cipherType === CipherItemType.LOGIN) {
              Column() {
                Text('登录信息')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 12 })

                TextInput({
                  placeholder: '用户名',
                  text: this.username
                })
                  .width('100%')
                  .height(48)
                  .borderRadius(8)
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => {
                    this.username = value;
                  })
                  .margin({ bottom: 12 })

                TextInput({
                  placeholder: '密码',
                  text: this.password
                })
                  .width('100%')
                  .height(48)
                  .borderRadius(8)
                  .padding({ left: 12, right: 12 })
                  .type(InputType.Password)
                  .onChange((value: string) => {
                    this.password = value;
                  })
                  .margin({ bottom: 12 })

                TextInput({
                  placeholder: '网址（可选）',
                  text: this.url
                })
                  .width('100%')
                  .height(48)
                  .borderRadius(8)
                  .padding({ left: 12, right: 12 })
                  .onChange((value: string) => {
                    this.url = value;
                  })
              }
              .width('100%')
              .padding(16)
              .margin({ bottom: 8 })
            }

            // 备注
            Column() {
              Text('备注')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })

              TextArea({
                placeholder: '备注（可选）',
                text: this.notes
              })
                .width('100%')
                .height(100)
                .borderRadius(8)
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .onChange((value: string) => {
                  this.notes = value;
                })
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
    .title('添加项目')
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .menus([this.EditItemBtn])
  }

  private getTypeName(type: number): string {
    switch (type) {
      case CipherItemType.LOGIN:
        return '登录';
      case CipherItemType.NOTE:
        return '安全笔记';
      case CipherItemType.CARD:
        return '卡片';
      case CipherItemType.IDENTITY:
        return '身份信息';
      default:
        return '未知';
    }
  }

  private canSave(): boolean {
    return this.name.trim().length > 0;
  }

  private async saveCipher() {
    if (!this.canSave()) {
      return;
    }

    this.isSubmitting = true;
    
    // 模拟保存
    setTimeout(() => {
      this.isSubmitting = false;
      this.pathInfos.pop();
    }, 1000);
  }
} 