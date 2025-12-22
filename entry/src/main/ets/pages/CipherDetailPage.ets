import { Cipher, CipherDetailParams, CipherField, CipherUri } from '../model/CipherModels';
import { CipherFieldType, CipherItemType } from '../utils/Constants';
import { CipherDetailViewModel } from '../viewmodel/CipherDetailViewModel';
import { CipherDetailTextItem } from '../component/CipherDetailTextItem';

@Builder
export function CipherDetailPageBuilder() {
  CipherDetailPage();
}

@Component
export struct CipherDetailPage {
  @State cipher: Cipher = {} as Cipher;
  @State isLoading: boolean = true;
  @State showHideField: boolean = false;
  @State isEditable: boolean = false;
  pathInfos: NavPathStack = new NavPathStack();
  private viewModel: CipherDetailViewModel = new CipherDetailViewModel();
  EditItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_edit.svg', 'action': () => {
      this.isEditable = true;
    }
  }
  DeleteItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_delete.svg', 'action': () => {
      this.deleteCipher();
    }
  }
  ConfirmEditBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_confirm.svg', 'action': () => {
      this.isEditable = false;
      // this.viewModel.updateCipher(this.cipher);
    }
  }
  CancelEditBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_cancel.svg', 'action': () => {
      this.isEditable = false;
      this.loadCipherDetail();
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

                  if (this.isEditable) {
                    TextInput({ text: this.cipher.notes })
                      .onChange((value: string) => {
                        this.cipher.notes = value;
                      })
                      .margin({ left: 16, right: 16 })
                  } else {
                    Text(this.cipher.notes)
                      .fontSize(14)
                      .fontColor('#666666')
                  }
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
      const param = ctx.pathInfo.param as CipherDetailParams;
      if (param.cipher && param.cipher.id) {
        this.cipher = param.cipher;
        this.viewModel.symmetricKey = param.symmetricKey;
        this.loadCipherDetail();
      }
    })
    .menus(this.isEditable ? [this.CancelEditBtn, this.ConfirmEditBtn] : [this.EditItemBtn, this.DeleteItemBtn])
  }

  @Builder
  buildLoginSection() {
    Column() {
      Text('登录信息')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // 用户名
      CipherDetailTextItem({
        label: '用户名',
        content: this.cipher.login?.username,
        isEditable: this.isEditable
      })

      // 密码
      CipherDetailTextItem({
        label: '密码',
        content: this.cipher.login?.password,
        showContent: this.showHideField,
        showHideButton: true,
        isEditable: this.isEditable
      })

      // 网址
      if (this.cipher.login?.uris && this.cipher.login.uris.length > 0) {
        ForEach(this.cipher.login.uris as CipherUri[], (uri: CipherUri) => {
          CipherDetailTextItem({
            label: '网站',
            content: uri.uri,
            isEditable: this.isEditable
          })
          // CipherDetailTextItem({
          //   label: '校验和',
          //   content: uri.uriChecksum,
          // })
        })
      }

      // TOTP
      if (this.cipher.login?.totp) {
        // TODO: 显示实时TOTP验证码
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
        CipherDetailTextItem({
          label: '持卡人',
          content: this.cipher.card.cardholderName,
          isEditable: this.isEditable
        })
      }

      // 品牌
      if (this.cipher.card?.brand) {
        CipherDetailTextItem({
          label: '品牌',
          content: this.cipher.card.brand,
          isEditable: this.isEditable
        })
      }

      // 卡号
      if (this.cipher.card?.number) {
        CipherDetailTextItem({
          label: '卡号',
          content: this.cipher.card.number,
          showContent: this.showHideField,
          showHideButton: true,
          isEditable: this.isEditable
        })
      }

      // 有效期
      if (this.cipher.card?.expMonth || this.cipher.card?.expYear) {
        CipherDetailTextItem({
          label: '有效期',
          content: `${this.cipher.card?.expMonth || ''}/${this.cipher.card?.expYear || ''}`,
          isEditable: this.isEditable
        })
      }

      // 安全码
      if (this.cipher.card?.code) {
        CipherDetailTextItem({
          label: '安全码',
          content: this.cipher.card.code,
          showContent: this.showHideField,
          showHideButton: true,
          isEditable: this.isEditable
        })
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
        CipherDetailTextItem({
          label: '姓名',
          content: `${this.cipher.identity?.firstName || ''} ${this.cipher.identity?.middleName ||
            ''} ${this.cipher.identity?.lastName || ''} ${this.cipher.identity?.title || ''}`.trim(),
          isEditable: this.isEditable
        })
      }

      // 用户名
      if (this.cipher.identity?.username) {
        CipherDetailTextItem({
          label: '用户名',
          content: this.cipher.identity.username,
          isEditable: this.isEditable
        })
      }

      // 公司
      if (this.cipher.identity?.company) {
        CipherDetailTextItem({
          label: '公司',
          content: this.cipher.identity.company,
          isEditable: this.isEditable
        })
      }

      // 社会保障号码
      if (this.cipher.identity?.ssn) {
        CipherDetailTextItem({
          label: '社会保障号码',
          content: this.cipher.identity.ssn,
          showContent: this.showHideField,
          showHideButton: true,
          isEditable: this.isEditable
        })
      }

      // 护照号码
      if (this.cipher.identity?.passportNumber) {
        CipherDetailTextItem({
          label: '社会保障号码',
          content: this.cipher.identity.passportNumber,
          showContent: this.showHideField,
          showHideButton: true,
          isEditable: this.isEditable
        })
      }

      // 许可证号码
      if (this.cipher.identity?.licenseNumber) {
        CipherDetailTextItem({
          label: '许可证号码',
          content: this.cipher.identity.licenseNumber,
          isEditable: this.isEditable
        })
      }

      // 邮箱
      if (this.cipher.identity?.email) {
        CipherDetailTextItem({
          label: '邮箱',
          content: this.cipher.identity.email,
          isEditable: this.isEditable
        })
      }

      // 电话
      if (this.cipher.identity?.phone) {
        CipherDetailTextItem({
          label: '电话',
          content: this.cipher.identity.phone,
          isEditable: this.isEditable
        })
      }


      // 地址
      if (this.cipher.identity?.address1 || this.cipher.identity?.city || this.cipher.identity?.state) {
        CipherDetailTextItem({
          label: '地址',
          content: `${this.cipher.identity?.address1 || ''} ${this.cipher.identity?.city ||
            ''} ${this.cipher.identity?.state || ''}`.trim(),
          isEditable: this.isEditable
        })
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
        CipherDetailTextItem({
          label: field.name,
          content: this.getFieldValue(field),
          showContent: (field.type == CipherFieldType.HIDE) ? this.showHideField : true,
          showHideButton: (field.type == CipherFieldType.HIDE) ? true : false,
          isEditable: this.isEditable
        })
      })
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  private deleteCipher() {
    // 删除密码项
    console.log('Delete cipher');
  }

  private getFieldValue(field: CipherField): string {
    let returnStr: string = '';
    if (field.type == CipherFieldType.BOOL) {
      (field.value == 'true') ? returnStr = '是' : returnStr = '否';
    } else {
      returnStr = field.value;
    }
    return returnStr;
  }
} 