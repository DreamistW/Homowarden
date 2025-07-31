import router from '@ohos.router';
import { Cipher, CipherField } from '../model/CipherModels';

@Entry
@Component
struct CipherDetailPage {
  @State cipher: Cipher = {} as Cipher;
  @State showPassword: boolean = false;
  @State isLoading: boolean = true;

  aboutToAppear() {
    const params = router.getParams();
    const cipherId: string = '';
    this.loadCipherDetail(cipherId);
  }

  private async loadCipherDetail(cipherId: string) {
    this.isLoading = true;
    // 模拟加载数据
    setTimeout(() => {
      this.cipher = {
        id: cipherId,
        name: 'GitHub',
        type: 1,
        login: {
          username: 'user@example.com',
          password: 'password123',
          uris: [{
            uri: 'https://github.com'
          }],
          passwordRevisionDate: '2025-07-31',
          totp: ''
        },
        notes: 'GitHub账户登录信息',
        favorite: true,
        creationDate: '2024-01-01',
        revisionDate: '2024-01-15',
        edit: true,
        folderId: '',
        organizationId: '',
        fields: [{} as CipherField],
        collectionIds: [],
        reprompt: 0
      };
      this.isLoading = false;
    }, 500);
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
          router.back();
        })

        Text('密码项详情')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        Blank()

        Button() {
          Text('编辑')
            .fontSize(16)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.navigateToEdit();
        })
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.cipher) {
        Scroll() {
          Column() {
            // 基本信息
            Column() {
              Text(this.cipher.name)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 8 })

              Text(this.getTypeName(this.cipher.type))
                .fontSize(14)
                .fontColor('#666666')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .margin({ bottom: 8 })

            // 登录信息
            if (this.cipher.type === 1) {
              Column() {
                Text('登录信息')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 12 })

                // 用户名
                Row() {
                  Text('用户名')
                    .fontSize(14)
                    .fontColor('#666666')
                    .width(80)

                  Text(this.cipher.login?.username)
                    .fontSize(14)
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })

                // 密码
                Row() {
                  Text('密码')
                    .fontSize(14)
                    .fontColor('#666666')
                    .width(80)

                  Text(this.showPassword ? this.cipher.login?.password : '••••••••')
                    .fontSize(14)
                    .layoutWeight(1)

                  Button() {
                    Text(this.showPassword ? '隐藏' : '显示')
                      .fontSize(12)
                  }
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    this.showPassword = !this.showPassword;
                  })
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })

                // 网址
                if (this.cipher.login?.uris) {
                  Row() {
                    Text('网址')
                      .fontSize(14)
                      .fontColor('#666666')
                      .width(80)

                    Text(this.cipher.login.uris[0].uri)
                      .fontSize(14)
                      .layoutWeight(1)
                      .fontColor('#007AFF')
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .margin({ bottom: 8 })
            }

            // 备注
            if (this.cipher.notes) {
              Column() {
                Text('备注')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 12 })

                Text(this.cipher.notes)
                  .fontSize(14)
                  .fontColor('#333333')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .margin({ bottom: 8 })
            }

            // 元数据
            Column() {
              Text('元数据')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })

              Row() {
                Text('创建时间')
                  .fontSize(14)
                  .fontColor('#666666')
                  .width(80)

                Text(this.cipher.creationDate)
                  .fontSize(14)
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })

              Row() {
                Text('修改时间')
                  .fontSize(14)
                  .fontColor('#666666')
                  .width(80)

                Text(this.cipher.revisionDate)
                  .fontSize(14)
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .margin({ bottom: 8 })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  private getTypeName(type: number): string {
    switch (type) {
      case 1:
        return '登录';
      case 2:
        return '安全笔记';
      case 3:
        return '卡片';
      case 4:
        return '身份信息';
      default:
        return '未知';
    }
  }

  private navigateToEdit() {
    router.pushUrl({
      url: 'pages/EditCipherPage',
      params: { cipherId: this.cipher.id }
    });
  }
} 