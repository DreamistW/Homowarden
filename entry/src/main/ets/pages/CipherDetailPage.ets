import { Cipher, CipherField, CipherUri } from '../model/CipherModels';
import { CipherItemType, CipherFieldType } from '../utils/Constants';
import { CipherDetailViewModel } from '../viewmodel/CipherDetailViewModel';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';

@Builder
export function CipherDetailPageBuilder() {
  CipherDetailPage();
}

@Component
export struct CipherDetailPage {
  @State cipher: Cipher = {} as Cipher;
  @State showPassword: boolean = false;
  @State isLoading: boolean = true;
  @State showCardNumber: boolean = false;
  @State showCardCode: boolean = false;
  @State showHideField: boolean = false;
  pathInfos: NavPathStack = new NavPathStack();
  private viewModel: CipherDetailViewModel = new CipherDetailViewModel();
  EditItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_edit.svg', 'action': () => {
      this.navigateToEdit();
    }
  }
  DeleteItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_delete.svg', 'action': () => {
      this.deleteCipher();
    }
  }

  private async loadCipherDetail() {
    this.isLoading = true;
    try {
      const cipherDetail = await this.viewModel.getCipherDetail(this.cipher);
      if (cipherDetail) {
        this.cipher = cipherDetail;
      }
    } catch (error) {
      console.error('Failed to load cipher detail:', error);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
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
        } else if (this.cipher && this.cipher.id) {
          Scroll() {
            Column() {
              Text(this.cipher.name)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 8 })

              // 登录信息
              if (this.cipher.type === CipherItemType.LOGIN && this.cipher.login) {
                this.buildLoginSection();
              }

              // 卡片信息
              if (this.cipher.type === CipherItemType.CARD && this.cipher.card) {
                this.buildCardSection();
              }

              // 身份信息
              if (this.cipher.type === CipherItemType.IDENTITY && this.cipher.identity) {
                this.buildIdentitySection();
              }

              // 安全笔记
              if (this.cipher.type === CipherItemType.NOTE && this.cipher.secureNote) {
                this.buildSecureNoteSection();
              }

              // 自定义字段
              if (this.cipher.fields && this.cipher.fields.length > 0) {
                this.buildCustomFieldsSection();
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
              .margin({ bottom: 8 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .align(Alignment.TopStart)
          .width('100%')
          .height('100%')
          .edgeEffect(EdgeEffect.Spring)
          .scrollable(ScrollDirection.Vertical)
        }
      }
      .width('100%')
      .height('100%')
    }
    .title('详情')
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
      const paramCipher = ctx.pathInfo.param as Cipher;
      if (paramCipher && paramCipher.id) {
        this.cipher = paramCipher;
        this.loadCipherDetail();
      }
    })
    .menus([this.EditItemBtn, this.DeleteItemBtn])
  }

  @Builder
  buildLoginSection() {
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

        Text(this.cipher.login?.username || '')
          .fontSize(14)
          .layoutWeight(1)

        Button() {
          Text('复制')
            .fontSize(12)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.copyText(this.cipher.login?.username);
        })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      // 密码
      Row() {
        Text('密码')
          .fontSize(14)
          .fontColor('#666666')
          .width(80)

        Text(this.showPassword ? (this.cipher.login?.password || '') : '••••••••')
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
        .margin({right: 8})

        Button() {
          Text('复制')
            .fontSize(12)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.copyText(this.cipher.login?.password);
        })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      // 网址
      if (this.cipher.login?.uris && this.cipher.login.uris.length > 0) {
        ForEach(this.cipher.login.uris as CipherUri[], (uri: CipherUri) => {
          Row() {
            Text('网站')
              .fontSize(14)
              .fontColor('#666666')
              .width(80)

            Text(uri.uri)
              .fontSize(14)
              .layoutWeight(1)
              .fontColor('#666666')

            Button() {
              Text('复制')
                .fontSize(12)
            }
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.copyText(uri.uri);
            })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        })
      }

      // TOTP
      if (this.cipher.login?.totp) {
        Row() {
          Text('TOTP')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.cipher.login.totp)
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(this.cipher.login?.totp);
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  @Builder
  buildCardSection() {
    Column() {
      Text('卡片信息')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // 持卡人姓名
      if (this.cipher.card?.cardholderName) {
        Row() {
          Text('持卡人')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.cipher.card.cardholderName)
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(this.cipher.card?.cardholderName);
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 品牌
      if (this.cipher.card?.brand) {
        Row() {
          Text('品牌')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.cipher.card.brand)
            .fontSize(14)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 卡号
      if (this.cipher.card?.number) {
        Row() {
          Text('卡号')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.showCardNumber ? this.cipher.card.number : '•••• •••• •••• ••••')
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text(this.showCardNumber ? '隐藏' : '显示')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showCardNumber = !this.showCardNumber;
          })
          .margin({right: 8})

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(this.cipher.card?.number);
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 有效期
      if (this.cipher.card?.expMonth || this.cipher.card?.expYear) {
        Row() {
          Text('有效期')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(`${this.cipher.card?.expMonth || ''}/${this.cipher.card?.expYear || ''}`)
            .fontSize(14)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 安全码
      if (this.cipher.card?.code) {
        Row() {
          Text('安全码')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.showCardCode ? this.cipher.card.code : '•••')
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text(this.showCardCode ? '隐藏' : '显示')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showCardCode = !this.showCardCode;
          })
          .margin({right: 8})

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(this.cipher.card?.code);
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  @Builder
  buildIdentitySection() {
    Column() {
      Text('身份信息')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // 姓名
      if (this.cipher.identity?.firstName || this.cipher.identity?.lastName) {
        Row() {
          Text('姓名')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(`${this.cipher.identity?.firstName || ''} ${this.cipher.identity?.lastName || ''}`.trim())
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(`${this.cipher.identity?.firstName || ''} ${this.cipher.identity?.lastName || ''}`.trim());
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 邮箱
      if (this.cipher.identity?.email) {
        Row() {
          Text('邮箱')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.cipher.identity.email)
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(this.cipher.identity?.email);
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 电话
      if (this.cipher.identity?.phone) {
        Row() {
          Text('电话')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.cipher.identity.phone)
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(this.cipher.identity?.phone);
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 公司
      if (this.cipher.identity?.company) {
        Row() {
          Text('公司')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(this.cipher.identity.company)
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(this.cipher.identity?.company);
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 地址
      if (this.cipher.identity?.address1 || this.cipher.identity?.city || this.cipher.identity?.state) {
        Row() {
          Text('地址')
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          Text(`${this.cipher.identity?.address1 || ''} ${this.cipher.identity?.city ||
            ''} ${this.cipher.identity?.state || ''}`.trim())
            .fontSize(14)
            .layoutWeight(1)

          Button() {
            Text('复制')
              .fontSize(12)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.copyText(`${this.cipher.identity?.address1 || ''} ${this.cipher.identity?.city ||
              ''} ${this.cipher.identity?.state || ''}`.trim());
          })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  @Builder
  buildSecureNoteSection() {
    Column() {
      Text('安全笔记')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  @Builder
  buildCustomFieldsSection() {
    Column() {
      Text('自定义字段')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      ForEach(this.cipher.fields as CipherField[], (field: CipherField) => {
        Row() {
          Text(field.name)
            .fontSize(14)
            .fontColor('#666666')
            .width(80)

          if (field.type === CipherFieldType.HIDE) {
            Text(this.showHideField ? field.value : '••••••••')
              .fontSize(14)
              .layoutWeight(1)

            Button() {
              Text(this.showHideField ? '隐藏' : '显示')
                .fontSize(12)
            }
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showHideField = !this.showHideField;
            })
            .margin({right: 8})

            Button() {
              Text('复制')
                .fontSize(12)
            }
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.copyText(field.value);
            })
          } else if (field.type === CipherFieldType.BOOL) {
            Text(field.value === 'true' ? '是' : '否')
              .fontSize(14)
              .layoutWeight(1)
          } else {
            Text(field.value)
              .fontSize(14)
              .layoutWeight(1)
            Button() {
              Text('复制')
                .fontSize(12)
            }
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.copyText(field.value);
            })
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      })
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  private navigateToEdit() {
    // 跳转到编辑页面
    console.log('Navigate to edit page');
  }

  private deleteCipher() {
    // 删除密码项
    console.log('Delete cipher');
  }

  private async copyText(text: string | null | undefined) {
    if(text == undefined || !text)
      return;
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to paste, error message: ${err.message}}`);
    }
  }
} 