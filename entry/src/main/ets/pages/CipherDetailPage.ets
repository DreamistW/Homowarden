import { Cipher, CipherDetailParams, CipherField, CipherUri } from '../model/CipherModels';
import {
  AUTO_LOCK,
  BACKGROUND_TIMESTAMP,
  CardBrandType,
  CipherFieldType,
  CipherItemType,
  IdentityTitleType,
  NEED_RELOAD_CIPHERS
} from '../utils/Constants';
import { CipherDetailViewModel } from '../viewmodel/CipherDetailViewModel';
import { CipherDetailTextItem } from '../component/CipherDetailTextItem';
import { CipherDetailDropdownItem } from '../component/CipherDetailDropdownItem';
import { IBestCheckbox, IBestDialog, IBestDropdownMenuOption, IBestStringNumber } from '@ibestservices/ibest-ui';
import { Logger } from '@nzy/logger';
import { DataPreferences } from '@abner/datastore';
import { EntryRouter } from '../../../../EntryRouter';

@Builder
export function CipherDetailPageBuilder() {
  CipherDetailPage();
}

@Component
export struct CipherDetailPage {
  @State cipher: Cipher = {} as Cipher;
  @State isLoading: boolean = true;
  @State isSaving: boolean = false;
  @State showHideField: boolean = false;
  @State isEditable: boolean = false;
  @State showDeleteDialog: boolean = false;
  @State selectedCardBrand: CardBrandType | string = CardBrandType.NONE;
  @State selectedIdentityTitle: IdentityTitleType | string = IdentityTitleType.NONE;
  pathInfos: NavPathStack = new NavPathStack();
  private viewModel: CipherDetailViewModel = new CipherDetailViewModel();
  private identityTitleGroup: string = 'identityTitleSelector';
  private cardBrandGroup: string = 'cardBrandSelector';
  // 下拉菜单选项
  private identityTitleOptions: IBestDropdownMenuOption[] = [
    { text: '无', value: IdentityTitleType.NONE },
    { text: '先生', value: IdentityTitleType.MR },
    { text: '夫人', value: IdentityTitleType.MRS },
    { text: '女士', value: IdentityTitleType.MISS },
    { text: 'Mx', value: IdentityTitleType.MX },
    { text: '博士', value: IdentityTitleType.DR }
  ];
  private cardBrandOptions: IBestDropdownMenuOption[] = [
    { text: '无', value: CardBrandType.NONE },
    { text: 'Visa', value: CardBrandType.VISA },
    { text: 'MasterCard', value: CardBrandType.MASTER },
    { text: 'American Express', value: CardBrandType.AME },
    { text: 'Discover', value: CardBrandType.DISCOVER },
    { text: 'Diners Club', value: CardBrandType.DINERS },
    { text: 'JCB', value: CardBrandType.JCB },
    { text: 'Maestro', value: CardBrandType.MAESTRO },
    { text: 'UnionPay', value: CardBrandType.UNIONPAY },
    { text: 'RuPay', value: CardBrandType.RUPAY },
    { text: '其他', value: CardBrandType.OTHER },
  ];

  // 将身份标题文本转换为枚举值
  private getIdentityTitleEnum(title: string | null | undefined): IdentityTitleType {
    if (!title) {
      return IdentityTitleType.NONE;
    }
    switch (title) {
      case '先生':
        return IdentityTitleType.MR;
      case '夫人':
        return IdentityTitleType.MRS;
      case '女士':
        return IdentityTitleType.MISS;
      case 'Mx':
        return IdentityTitleType.MX;
      case '博士':
        return IdentityTitleType.DR;
      default:
        return IdentityTitleType.NONE;
    }
  }

  // 将卡品牌文本转换为枚举值
  private getCardBrandEnum(brand: string | null | undefined): CardBrandType {
    if (!brand) {
      return CardBrandType.NONE;
    }
    switch (brand) {
      case 'Visa':
        return CardBrandType.VISA;
      case 'MasterCard':
        return CardBrandType.MASTER;
      case 'American Express':
        return CardBrandType.AME;
      case 'Discover':
        return CardBrandType.DISCOVER;
      case 'Diners Club':
        return CardBrandType.DINERS;
      case 'JCB':
        return CardBrandType.JCB;
      case 'Maestro':
        return CardBrandType.MAESTRO;
      case 'UnionPay':
        return CardBrandType.UNIONPAY;
      case 'RuPay':
        return CardBrandType.RUPAY;
      case '其他':
        return CardBrandType.OTHER;
      default:
        return CardBrandType.NONE;
    }
  }

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
    'value': '', 'icon': 'resources/base/media/icon_confirm.svg', 'action': async () => {
      await this.saveCipher();
    }
  }
  CancelEditBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_cancel.svg', 'action': () => {
      this.isEditable = false;
      this.loadCipherDetail();
    }
  }
  RestoreItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_restore.svg', 'action': async () => {
      await this.restoreCipher();
    }
  }

  @Builder
  deleteCipherConfirmDialogContent() {
    Column() {
      if (this.cipher.deletedDate) {
        Text(`确定要彻底删除密码项"${this.cipher.name}"吗?`)
          .fontSize(16)
          .margin(12)
      } else {
        Text(`确定要将密码项"${this.cipher.name}"送至回收站吗?`)
          .fontSize(16)
          .margin(12)
      }
    }
  }

  /**
   * 加载密码项详情
   */
  private async loadCipherDetail() {
    this.isLoading = true;
    try {
      const cipherDetail = await this.viewModel.getCipherDetail(this.cipher);
      if (cipherDetail) {
        this.cipher = cipherDetail;
        // 初始化下拉菜单的选中值
        if (this.cipher.card?.brand) {
          this.selectedCardBrand = this.getCardBrandEnum(this.cipher.card.brand);
        }
        if (this.cipher.identity?.title) {
          this.selectedIdentityTitle = this.getIdentityTitleEnum(this.cipher.identity.title);
        }
      }
    } catch (error) {
      Logger.error('Failed to load cipher detail:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 保存密码项
   */
  private async saveCipher() {
    this.isSaving = true;
    try {
      // 调用 ViewModel 的 updateCipher 方法
      await this.viewModel.updateCipher(this.cipher);
      // 保存成功，退出编辑模式
      this.isEditable = false;
      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 1);
    } catch (error) {
      Logger.error('Failed to save cipher:', error);
    } finally {
      this.isSaving = false;
    }
  }

  /**
   * 还原密码项
   */
  private async restoreCipher() {
    try {
      await this.viewModel.restoreCipher(this.cipher);
      this.cipher.deletedDate = null;
      // 显示成功提示
      const promptAction = this.getUIContext().getPromptAction();
      promptAction.showToast({
        message: '还原成功',
        duration: 2000
      });
    } catch (error) {
      Logger.error('Failed to restore cipher:', error);
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

              // 主密码重新提示
              if (this.isEditable) {
                IBestCheckbox({
                  value: this.cipher.reprompt == 1 ? true : false,
                  label: '主密码重新提示',
                  onChange: (checked: boolean | IBestStringNumber) => {
                    if (checked) {
                      this.cipher.reprompt = 1;
                    } else {
                      this.cipher.reprompt = 0;
                    }
                  }
                })
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

        // 删除确认对话框
        IBestDialog({
          visible: this.showDeleteDialog,
          showCancelButton: true,
          closeOnClickOverlay: false,
          title: '删除密码项',
          defaultBuilder: () => this.deleteCipherConfirmDialogContent(),
          onConfirm: async () => {
            return await this.doDeleteCipher();
          },
          onCancel: () => {
            this.showDeleteDialog = false;
            return true;
          }
        })
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
    .menus(this.isEditable ? [this.CancelEditBtn, this.ConfirmEditBtn] :
      this.cipher.deletedDate ? [this.RestoreItemBtn, this.DeleteItemBtn] : [this.EditItemBtn, this.DeleteItemBtn])
    .onActive(() => {
      const autoLockStatus = DataPreferences.getInstance().getSync<number>(AUTO_LOCK);
      if (autoLockStatus == 1) {
        const currentTime = Math.floor(Date.now() / 1000);
        const backgroundTime = DataPreferences.getInstance().getSync<number>(BACKGROUND_TIMESTAMP);
        if (currentTime - backgroundTime > 120) {
          this.pathInfos.pushPath({ name: EntryRouter.BiometricAuthPage });
        }
      }
    })
    .onHidden(() => {
      DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
    })
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
        content: this.cipher.login?.username ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.login) {
            this.cipher.login.username = value;
          }
        }
      })

      // 密码
      CipherDetailTextItem({
        label: '密码',
        content: this.cipher.login?.password ?? '',
        showContent: this.showHideField,
        showHideButton: true,
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.login) {
            this.cipher.login.password = value;
          }
        }
      })

      // 网址
      if (this.cipher.login?.uris && this.cipher.login.uris.length > 0) {
        ForEach(this.cipher.login.uris as CipherUri[], (uri: CipherUri) => {
          CipherDetailTextItem({
            label: '网站',
            content: uri.uri,
            isEditable: this.isEditable,
            onValueChange: (value: string) => {
              uri.uri = value;
            }
          })
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
      CipherDetailTextItem({
        label: '持卡人姓名',
        content: this.cipher.card?.cardholderName ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.card) {
            this.cipher.card.cardholderName = value;
          }
        }
      })

      // 卡号
      CipherDetailTextItem({
        label: '号码',
        content: this.cipher.card?.number ?? '',
        showContent: this.showHideField,
        showHideButton: true,
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.card) {
            this.cipher.card.number = value;
          }
        }
      })

      // 品牌
      CipherDetailDropdownItem({
        label: '品牌',
        content: this.cipher.card?.brand ?? '',
        dropdownOptions: this.cardBrandOptions,
        groupId: this.cardBrandGroup,
        selectedValue: this.selectedCardBrand,
        onValueChange: (value) => {
          this.selectedCardBrand = value as CardBrandType;
          switch (value) {
            case CardBrandType.NONE:
              this.cipher.card!.brand = '';
              break;
            case CardBrandType.VISA:
              this.cipher.card!.brand = 'Visa';
              break;
            case CardBrandType.MASTER:
              this.cipher.card!.brand = 'MasterCard';
              break;
            case CardBrandType.AME:
              this.cipher.card!.brand = 'American Express';
              break;
            case CardBrandType.DISCOVER:
              this.cipher.card!.brand = 'Discover';
              break;
            case CardBrandType.DINERS:
              this.cipher.card!.brand = 'Diners Club';
              break;
            case CardBrandType.JCB:
              this.cipher.card!.brand = 'JCB';
              break;
            case CardBrandType.MAESTRO:
              this.cipher.card!.brand = 'Maestro';
              break;
            case CardBrandType.UNIONPAY:
              this.cipher.card!.brand = 'UnionPay';
              break;
            case CardBrandType.RUPAY:
              this.cipher.card!.brand = 'RuPay';
              break;
            case CardBrandType.OTHER:
              this.cipher.card!.brand = '其他';
              break;
          }
        },
        isEditable: this.isEditable
      })

      // 过期月份
      CipherDetailTextItem({
        label: '过期月份',
        content: this.cipher.card?.expMonth ?? '',
        isEditable: this.isEditable,
        isNumberOnly: true,
        onValueChange: (value: string) => {
          // 校验月份：只允许1-12
          const month = parseInt(value);
          if (value === '' || (!isNaN(month) && month >= 1 && month <= 12)) {
            if (this.cipher.card) {
              this.cipher.card.expMonth = value;
            }
          }
        }
      })

      // 过期年份
      CipherDetailTextItem({
        label: '过期年份',
        content: this.cipher.card?.expYear ?? '',
        isEditable: this.isEditable,
        isNumberOnly: true,
        onValueChange: (value: string) => {
          // 校验年份：只允许合理的公元年份（1900-9999）
          const year = parseInt(value);
          if (value === '' || (!isNaN(year) && year >= 1900 && year <= 9999)) {
            if (this.cipher.card) {
              this.cipher.card.expYear = value;
            }
          }
        }
      })

      // 安全码
      CipherDetailTextItem({
        label: '安全码',
        content: this.cipher.card?.code ?? '',
        showContent: this.showHideField,
        showHideButton: true,
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.card) {
            this.cipher.card.code = value;
          }
        }
      })
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

      // 称呼
      CipherDetailDropdownItem({
        label: '称呼',
        content: this.cipher.identity?.title ?? '',
        dropdownOptions: this.identityTitleOptions,
        groupId: this.identityTitleGroup,
        selectedValue: this.selectedIdentityTitle,
        onValueChange: (value) => {
          this.selectedIdentityTitle = value as IdentityTitleType;
          switch (value) {
            case IdentityTitleType.NONE:
              this.cipher.identity!.title = '';
              break;
            case IdentityTitleType.MR:
              this.cipher.identity!.title = '先生';
              break;
            case IdentityTitleType.MRS:
              this.cipher.identity!.title = '夫人';
              break;
            case IdentityTitleType.MISS:
              this.cipher.identity!.title = '女士';
              break;
            case IdentityTitleType.MX:
              this.cipher.identity!.title = 'Mx';
              break;
            case IdentityTitleType.DR:
              this.cipher.identity!.title = '博士';
              break;
          }
        },
        isEditable: this.isEditable
      })

      // 名
      CipherDetailTextItem({
        label: '名',
        content: this.cipher.identity?.firstName ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.firstName = value;
          }
        }
      })

      // 中间名
      CipherDetailTextItem({
        label: '中间名',
        content: this.cipher.identity?.middleName ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.middleName = value;
          }
        }
      })

      // 姓
      CipherDetailTextItem({
        label: '姓',
        content: this.cipher.identity?.lastName ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.lastName = value;
          }
        }
      })

      // 用户名
      CipherDetailTextItem({
        label: '用户名',
        content: this.cipher.identity?.username ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.username = value;
          }
        }
      })

      // 公司
      CipherDetailTextItem({
        label: '公司',
        content: this.cipher.identity?.company ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.company = value;
          }
        }
      })

      // 社会保障号码
      CipherDetailTextItem({
        label: '社会保障号码',
        content: this.cipher.identity?.ssn ?? '',
        showContent: this.showHideField,
        showHideButton: true,
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.ssn = value;
          }
        }
      })

      // 护照号码
      CipherDetailTextItem({
        label: '护照号码',
        content: this.cipher.identity?.passportNumber ?? '',
        showContent: this.showHideField,
        showHideButton: true,
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.passportNumber = value;
          }
        }
      })

      // 许可证号码
      CipherDetailTextItem({
        label: '许可证号码',
        content: this.cipher.identity?.licenseNumber ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.licenseNumber = value;
          }
        }
      })

      // 电子邮箱
      CipherDetailTextItem({
        label: '电子邮箱',
        content: this.cipher.identity?.email ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.email = value;
          }
        }
      })

      // 电话
      CipherDetailTextItem({
        label: '电话',
        content: this.cipher.identity?.phone ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.phone = value;
          }
        }
      })

      // 地址1
      CipherDetailTextItem({
        label: '地址 1',
        content: this.cipher.identity?.address1 ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.address1 = value;
          }
        }
      })

      // 地址2
      CipherDetailTextItem({
        label: '地址 2',
        content: this.cipher.identity?.address2 ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.address2 = value;
          }
        }
      })

      // 地址3
      CipherDetailTextItem({
        label: '地址 3',
        content: this.cipher.identity?.address3 ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.address3 = value;
          }
        }
      })

      // 市/镇
      CipherDetailTextItem({
        label: '市/镇',
        content: this.cipher.identity?.city ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.city = value;
          }
        }
      })

      // 州/省
      CipherDetailTextItem({
        label: '州/省',
        content: this.cipher.identity?.state ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.state = value;
          }
        }
      })

      // 邮政编码
      CipherDetailTextItem({
        label: '邮政编码',
        content: this.cipher.identity?.postalCode ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.postalCode = value;
          }
        }
      })

      // 国家
      CipherDetailTextItem({
        label: '国家',
        content: this.cipher.identity?.country ?? '',
        isEditable: this.isEditable,
        onValueChange: (value: string) => {
          if (this.cipher.identity) {
            this.cipher.identity.country = value;
          }
        }
      })
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
    this.showDeleteDialog = true;
  }

  /**
   * 执行删除密码项
   */
  private async doDeleteCipher(): Promise<boolean> {
    try {
      await this.viewModel.deleteCipher(this.cipher.id, this.cipher.deletedDate ? true : false);
      Logger.info(`Cipher ${this.cipher.id} deleted successfully`);

      // 显示成功提示
      const promptAction = this.getUIContext().getPromptAction();
      promptAction.showToast({
        message: '删除成功',
        duration: 2000
      });

      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 1);

      // 返回上一页
      this.pathInfos.pop();
      return true;
    } catch (error) {
      Logger.error('Failed to delete cipher:', error);

      // 显示失败提示
      const promptAction = this.getUIContext().getPromptAction();
      promptAction.showToast({
        message: `删除失败, 错误信息: ${error}`,
        duration: 2000
      });

      this.showDeleteDialog = false;
      return false;
    }
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