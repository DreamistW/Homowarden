import { DataPreferences } from '@abner/datastore';
import { AppDropdown } from '../component/AppDropdown';
import { AppToast } from '../utils/AppToast';
import { TotpEditItem } from '../component/TotpEditItem';
import { CustomFieldEditItem } from '../component/CustomFieldEditItem';
import { AdaptiveIconButton, AdaptiveTextButton } from '../component/AdaptiveButton';
import { GeneratorPanel, GeneratorPanelMode } from '../component/GeneratorPanel';
import { CipherField } from '../model/CipherModels';
import {
  CardBrandType,
  CipherFieldType,
  CipherItemType,
  IdentityTitleType,
  NEED_RELOAD_CIPHERS
} from '../utils/Constants';
import { AddCipherViewModel } from '../viewmodel/AddCipherViewModel';
import { hdsMaterial, HdsNavDestination, HdsNavigationBadgeIconOptions } from '@kit.UIDesignKit';
import { VaultChangeNotifier } from '../utils/VaultChangeNotifier';
import { AppOptionFactory } from '../localization/AppOptionFactory';
import { DetailRouter } from '../utils/DetailRouter';
import { DetailLeaveGuard, DetailLeaveHandler } from '../utils/DetailLeaveGuard';
import { ConfirmDialog } from '../component/ConfirmDialog';

@Builder
export function AddCipherPageBuilder() {
  AddCipherPage();
}

@Component
export struct AddCipherPage {
  @StorageLink('activeSplitView') isSplitView: boolean = false;
  @State viewModel: AddCipherViewModel = new AddCipherViewModel();
  @State cipherType: CipherItemType = CipherItemType.LOGIN;
  @State isSubmitting: boolean = false;
  @State identityTitle: IdentityTitleType = IdentityTitleType.NONE;
  @State cardBrand: CardBrandType = CardBrandType.NONE;
  @State totpSecret: string = '';
  @State newFieldType: CipherFieldType = CipherFieldType.TEXT;
  // 登录用户名/密码的受控镜像，便于生成器回填后即时显示
  @State loginUsername: string = '';
  @State loginPassword: string = '';
  // 生成器面板状态
  @State showGenSheet: boolean = false;
  @State genMode: GeneratorPanelMode = GeneratorPanelMode.PASSWORD;
  allowSave: boolean = false;
  pathInfos: NavPathStack = new NavPathStack();
  // 表单初始快照，用于判断是否有未保存改动
  private initialViewModelSnapshot: string = '';
  private leaveHandler: DetailLeaveHandler = (onLeave: () => void, onStay: () => void): void => {
    if (this.hasUnsavedChanges()) {
      this.showDiscardConfirm(onLeave, onStay);
      return;
    }
    onLeave();
  };

  aboutToDisappear(): void {
    DetailLeaveGuard.unregister(this.leaveHandler);
    // 旋转跨栈迁移会销毁本页，随之关闭未决确认框（等同取消）
    this.confirmController.close();
  }

  @State confirmTitle: ResourceStr = '';
  @State confirmMessage: ResourceStr = '';
  @State confirmText: ResourceStr = $r('app.string.common_confirm');
  private confirmAction: () => Promise<boolean> = async () => true;
  private confirmCancel: () => void = () => {};
  private confirmController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: $confirmTitle,
      message: $confirmMessage,
      confirmText: $confirmText,
      onConfirm: async (): Promise<boolean> => {
        return await this.confirmAction();
      },
      onCancel: (): void => {
        this.confirmCancel();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  private showConfirm(title: ResourceStr, message: ResourceStr, action: () => void,
    cancel: () => void = () => {}, confirmText: ResourceStr = $r('app.string.common_confirm')): void {
    this.confirmTitle = title;
    this.confirmMessage = message;
    this.confirmText = confirmText;
    this.confirmAction = async (): Promise<boolean> => {
      action();
      return true;
    };
    this.confirmCancel = cancel;
    this.confirmController.open();
  }
  ConfirmBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_confirm'),
      icon: $r('app.media.icon_confirm'),
      isEnabled: true,
      action: () => {
        this.saveCipher();
      }
    }
  }
  itemTypeGroup: string = 'itemTypeSelector';

  private identityTitleFromValue(value: number): IdentityTitleType {
    switch (value) {
      case IdentityTitleType.MR:
        return IdentityTitleType.MR;
      case IdentityTitleType.MRS:
        return IdentityTitleType.MRS;
      case IdentityTitleType.MISS:
        return IdentityTitleType.MISS;
      case IdentityTitleType.MX:
        return IdentityTitleType.MX;
      case IdentityTitleType.DR:
        return IdentityTitleType.DR;
      default:
        return IdentityTitleType.NONE;
    }
  }

  private cardBrandFromValue(value: number): CardBrandType {
    switch (value) {
      case CardBrandType.VISA:
        return CardBrandType.VISA;
      case CardBrandType.MASTER:
        return CardBrandType.MASTER;
      case CardBrandType.AME:
        return CardBrandType.AME;
      case CardBrandType.DISCOVER:
        return CardBrandType.DISCOVER;
      case CardBrandType.DINERS:
        return CardBrandType.DINERS;
      case CardBrandType.JCB:
        return CardBrandType.JCB;
      case CardBrandType.MAESTRO:
        return CardBrandType.MAESTRO;
      case CardBrandType.UNIONPAY:
        return CardBrandType.UNIONPAY;
      case CardBrandType.RUPAY:
        return CardBrandType.RUPAY;
      case CardBrandType.OTHER:
        return CardBrandType.OTHER;
      default:
        return CardBrandType.NONE;
    }
  }

  private customFieldTypeFromValue(value: number): CipherFieldType {
    switch (value) {
      case CipherFieldType.HIDE:
        return CipherFieldType.HIDE;
      case CipherFieldType.BOOL:
        return CipherFieldType.BOOL;
      default:
        return CipherFieldType.TEXT;
    }
  }

  @Builder
  private cipherTypeOption(type: CipherItemType, label: Resource) {
    Row({ space: 8 }) {
      Radio({ value: `${type}`, group: this.itemTypeGroup })
        .checked(this.cipherType === type)
        .radioStyle({
          checkedBackgroundColor: $r('app.color.brand_accent_color')
        })
        .accessibilityText(label)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.cipherType = type;
            this.viewModel.type = type;
          }
        })
      Text(label)
        .fontSize(14)
        .accessibilityLevel('no')
    }
    .width(120)
    .alignItems(VerticalAlign.Center)
  }

  // 生成器底部面板内容：按当前模式渲染，"使用"回填到对应输入框
  @Builder
  generatorSheet() {
    GeneratorPanel({
      mode: this.genMode,
      onUse: (value: string) => {
        if (this.genMode === GeneratorPanelMode.PASSWORD) {
          this.loginPassword = value;
          this.viewModel.loginItem.password = value;
        } else {
          this.loginUsername = value;
          this.viewModel.loginItem.username = value;
        }
        this.showGenSheet = false;
      }
    })
  }

  build() {
    HdsNavDestination() {
      Scroll() {
        Column() {
          Column() {
            Text($r('app.string.cipher_type'))
              .fontSize(14)
              .margin(8)

            Row({ space: 16 }) {
              this.cipherTypeOption(CipherItemType.LOGIN, $r('app.string.vault_type_login'))
              this.cipherTypeOption(CipherItemType.NOTE, $r('app.string.vault_type_note'))
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .justifyContent(FlexAlign.Center)

            Text().margin(8)

            Row({ space: 16 }) {
              this.cipherTypeOption(CipherItemType.CARD, $r('app.string.vault_type_card'))
              this.cipherTypeOption(CipherItemType.IDENTITY, $r('app.string.vault_type_identity'))
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .justifyContent(FlexAlign.Center)
          }

          // 名称
          Text($r('app.string.cipher_item_name'))
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 20,
              bottom: 4
            })
          TextInput()
            .accessibilityText($r('app.string.cipher_item_name'))
            .onChange((v: string) => {
              this.viewModel.name = v;
              this.canSave();
            })
            .margin({ left: 16, right: 16 })

          if (this.cipherType == CipherItemType.LOGIN) {
            // 用户名
            Row() {
              Text($r('app.string.cipher_username'))
                .fontSize(14)
                .fontColor('#666666')
                .width(80)
              TextInput({ text: this.loginUsername })
                .accessibilityText($r('app.string.cipher_username'))
                .layoutWeight(1)
                .margin({ left: 8, right: 8 })
                .onChange((v: string) => {
                  this.loginUsername = v;
                  this.viewModel.loginItem.username = v;
                })
              AdaptiveIconButton({
                icon: $r('app.media.icon_password'),
                accessibilityLabel: $r('app.string.accessibility_generate'),
                barWidth: 32,
                barHeight: 32,
                iconWidth: 20,
                iconHeight: 20,
                contentPadding: 4,
                barBottomMargin: 0,
                onButtonClick: () => {
                  this.genMode = GeneratorPanelMode.USERNAME;
                  this.showGenSheet = true;
                }
              })
            }
            .margin({
              left: 16,
              right: 16,
              top: 20,
              bottom: 8
            })

            // 密码
            Row() {
              Text($r('app.string.cipher_password'))
                .fontSize(14)
                .fontColor('#666666')
                .width(80)
              TextInput({ text: this.loginPassword, placeholder: $r('app.string.login_password_placeholder') })
                .accessibilityText($r('app.string.cipher_password'))
                .type(InputType.Password)
                .layoutWeight(1)
                .margin({ left: 8, right: 8 })
                .onChange((v: string) => {
                  this.loginPassword = v;
                  this.viewModel.loginItem.password = v;
                })
              AdaptiveIconButton({
                icon: $r('app.media.icon_password'),
                accessibilityLabel: $r('app.string.accessibility_generate'),
                barWidth: 32,
                barHeight: 32,
                iconWidth: 20,
                iconHeight: 20,
                contentPadding: 4,
                barBottomMargin: 0,
                onButtonClick: () => {
                  this.genMode = GeneratorPanelMode.PASSWORD;
                  this.showGenSheet = true;
                }
              })
            }
            .margin({
              left: 16,
              right: 16,
              top: 20,
              bottom: 8
            })

            // 网站
            Text($r('app.string.cipher_website'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput({ placeholder: $r('app.string.cipher_website_example') })
              .accessibilityText($r('app.string.cipher_website'))
              .onChange((v: string) => {
                this.viewModel.loginUri.uri = v;
              })
              .margin({ left: 16, right: 16 })

            // TOTP两步验证
            TotpEditItem({
              totpSecret: $totpSecret,
              onSecretChange: (value: string) => {
                this.viewModel.loginItem.totp = value;
              }
            }).margin({ left: 16, right: 16 })
          } else if (this.cipherType == CipherItemType.IDENTITY) {
            // 称呼
            Text($r('app.string.cipher_identity_title'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            AppDropdown({
              options: AppOptionFactory.identityTitles(),
              value: this.identityTitle,
              accessibilityLabel: $r('app.string.cipher_identity_title'),
              onChange: (value: number) => {
                this.identityTitle = this.identityTitleFromValue(value);
                this.viewModel.setIdentityTitle(this.identityTitle);
              }
            })
              .margin({ left: 16, right: 16 })

            // 名
            Text($r('app.string.cipher_first_name'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_first_name'))
              .onChange((v: string) => {
                this.viewModel.identityItem.firstName = v;
              })
              .margin({ left: 16, right: 16 })
            // 中间名
            Text($r('app.string.cipher_middle_name'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_middle_name'))
              .onChange((v: string) => {
                this.viewModel.identityItem.middleName = v;
              })
              .margin({ left: 16, right: 16 })
            // 姓
            Text($r('app.string.cipher_last_name'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_last_name'))
              .onChange((v: string) => {
                this.viewModel.identityItem.lastName = v;
              })
              .margin({ left: 16, right: 16 })
            // 用户名
            Text($r('app.string.cipher_username'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_username'))
              .onChange((v: string) => {
                this.viewModel.identityItem.username = v;
              })
              .margin({ left: 16, right: 16 })
            // 公司
            Text($r('app.string.cipher_company'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_company'))
              .onChange((v: string) => {
                this.viewModel.identityItem.company = v;
              })
              .margin({ left: 16, right: 16 })
            // 社会保障号码
            Text($r('app.string.cipher_ssn'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput({ placeholder: $r('app.string.cipher_ssn') })
              .accessibilityText($r('app.string.cipher_ssn'))
              .onChange((v: string) => {
                this.viewModel.identityItem.ssn = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.Password)
            // 护照号码
            Text($r('app.string.cipher_passport'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput({ placeholder: $r('app.string.cipher_passport') })
              .accessibilityText($r('app.string.cipher_passport'))
              .onChange((v: string) => {
                this.viewModel.identityItem.passportNumber = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.Password)
            // 许可证号码
            Text($r('app.string.cipher_license'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_license'))
              .onChange((v: string) => {
                this.viewModel.identityItem.licenseNumber = v;
              })
              .margin({ left: 16, right: 16 })
            // 电子邮箱
            Text($r('app.string.cipher_email'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_email'))
              .onChange((v: string) => {
                this.viewModel.identityItem.email = v;
              })
              .margin({ left: 16, right: 16 })
            // 电话
            Text($r('app.string.cipher_phone'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_phone'))
              .onChange((v: string) => {
                this.viewModel.identityItem.phone = v;
              })
              .margin({ left: 16, right: 16 })
            // 地址1
            Text($r('app.string.cipher_address1'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_address1'))
              .onChange((v: string) => {
                this.viewModel.identityItem.address1 = v;
              })
              .margin({ left: 16, right: 16 })
            // 地址2
            Text($r('app.string.cipher_address2'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_address2'))
              .onChange((v: string) => {
                this.viewModel.identityItem.address2 = v;
              })
              .margin({ left: 16, right: 16 })
            // 地址3
            Text($r('app.string.cipher_address3'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_address3'))
              .onChange((v: string) => {
                this.viewModel.identityItem.address3 = v;
              })
              .margin({ left: 16, right: 16 })
            // 市/镇
            Text($r('app.string.cipher_city'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_city'))
              .onChange((v: string) => {
                this.viewModel.identityItem.city = v;
              })
              .margin({ left: 16, right: 16 })
            // 州/省
            Text($r('app.string.cipher_state'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_state'))
              .onChange((v: string) => {
                this.viewModel.identityItem.state = v;
              })
              .margin({ left: 16, right: 16 })
            // 邮政编码
            Text($r('app.string.cipher_postal_code'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_postal_code'))
              .onChange((v: string) => {
                this.viewModel.identityItem.postalCode = v;
              })
              .margin({ left: 16, right: 16 })
            // 国家
            Text($r('app.string.cipher_country'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_country'))
              .onChange((v: string) => {
                this.viewModel.identityItem.country = v;
              })
              .margin({ left: 16, right: 16 })
          } else if (this.cipherType == CipherItemType.CARD) {
            // 姓名
            Text($r('app.string.cipher_cardholder'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_cardholder'))
              .onChange((v: string) => {
                this.viewModel.cardItem.cardholderName = v;
              })
              .margin({ left: 16, right: 16 })
            // 号码
            Text($r('app.string.cipher_number'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput({ placeholder: $r('app.string.cipher_number') })
              .accessibilityText($r('app.string.cipher_number'))
              .onChange((v: string) => {
                this.viewModel.cardItem.number = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.Password)
            // 品牌
            Text($r('app.string.cipher_brand'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            AppDropdown({
              options: AppOptionFactory.cardBrands(),
              value: this.cardBrand,
              accessibilityLabel: $r('app.string.cipher_brand'),
              onChange: (value: number) => {
                this.cardBrand = this.cardBrandFromValue(value);
                this.viewModel.setCardBrand(this.cardBrand);
              }
            })
              .margin({ left: 16, right: 16 })

            // 过期月份
            Text($r('app.string.cipher_exp_month'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_exp_month'))
              .onChange((v: string) => {
                // 校验月份：只允许1-12
                const month = parseInt(v);
                if (v === '' || (!isNaN(month) && month >= 1 && month <= 12)) {
                  this.viewModel.cardItem.expMonth = v;
                }
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.NUMBER_DECIMAL)

            // 过期年份
            Text($r('app.string.cipher_exp_year'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput()
              .accessibilityText($r('app.string.cipher_exp_year'))
              .onChange((v: string) => {
                // 校验年份：只允许合理的公元年份（1900-9999）
                const year = parseInt(v);
                if (v === '' || (!isNaN(year) && year >= 1900 && year <= 9999)) {
                  this.viewModel.cardItem.expYear = v;
                }
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.NUMBER_DECIMAL)
            // 安全码
            Text($r('app.string.cipher_security_code'))
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            TextInput({ placeholder: $r('app.string.cipher_security_code') })
              .accessibilityText($r('app.string.cipher_security_code'))
              .onChange((v: string) => {
                this.viewModel.cardItem.code = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.NUMBER_PASSWORD)
          }

          // 备注
          Text($r('app.string.cipher_notes'))
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 12,
              bottom: 4
            })
          TextArea({ text: this.viewModel.notes })
            .accessibilityText($r('app.string.cipher_notes'))
            .constraintSize({ minHeight: 80 })
            .onChange((v: string) => {
              this.viewModel.notes = v;
            })
            .margin({ left: 16, right: 16, bottom: 24 })

          // 自定义字段区块：所有 cipher 类型共用，与新增密码项主流程一致
          Text($r('app.string.cipher_custom_fields'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 16, right: 16, top: 16, bottom: 8 })

          ForEach(this.viewModel.fields, (field: CipherField) => {
            Column() {
              CustomFieldEditItem({
                field: field,
                onNameChange: (v: string) => {
                  field.name = v;
                  this.viewModel.fields = [...this.viewModel.fields];
                },
                onValueChange: (v: string) => {
                  field.value = v;
                  this.viewModel.fields = [...this.viewModel.fields];
                },
                onBoolChange: (v: boolean) => {
                  field.value = v ? 'true' : 'false';
                  this.viewModel.fields = [...this.viewModel.fields];
                },
                onRemove: () => {
                  this.viewModel.fields = this.viewModel.fields.filter(f => f !== field);
                }
              })
            }
            .padding({ left: 16, right: 16 })
          }, (field: CipherField) => field.itemId ?? field.name)

          Row({ space: 8 }) {
            AppDropdown({
              options: AppOptionFactory.customFieldTypes(),
              value: this.newFieldType,
              accessibilityLabel: $r('app.string.cipher_field_type'),
              onChange: (value: number) => {
                this.newFieldType = this.customFieldTypeFromValue(value);
              }
            })
              .layoutWeight(1)

            AdaptiveTextButton({
              text: $r('app.string.cipher_add_field'),
              barWidth: 120,
              barHeight: 40,
              fontSize: 14,
              barBottomMargin: 0,
              onButtonClick: () => {
                this.viewModel.addField(this.newFieldType);
                this.viewModel.fields = [...this.viewModel.fields];
              }
            })
          }
          .margin({ left: 16, right: 16, top: 8, bottom: 24 })

          // 错误提示
          if (this.viewModel.errorMessage && this.viewModel.errorMessage.length > 0) {
            Text(this.viewModel.errorMessage === 'cipher_name_required' ?
              $r('app.string.cipher_name_required') : $r('app.string.error_save_failed'))
              .fontColor(Color.Red)
              .fontSize(14)
              .margin({ left: 16, right: 16, bottom: 16 })
          }
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
    }
    .titleBar({
      content: {
        title: {
          mainTitle: $r('app.string.cipher_add_title')
        },
        menu: {
          value: [this.ConfirmBtn]
        }
      },
      enableComponentSafeArea: true,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .hideBackButton(this.isSplitView)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
      const param = ctx.pathInfo.param as string;
      if (param) {
        this.viewModel.symmetricKey = param;
      }
      this.initialViewModelSnapshot = JSON.stringify(this.viewModel);
      DetailLeaveGuard.register(this.leaveHandler);
    })
    .onBackPressed((): boolean => {
      if (this.hasUnsavedChanges()) {
        this.showDiscardConfirm(() => {
          DetailRouter.closeDetail();
        });
        return true;
      }
      if (this.pathInfos.getAllPathName().length > 0) {
        DetailRouter.closeDetail();
        return true;
      }
      return false;
    })
    .bindSheet($$this.showGenSheet, this.generatorSheet,
      { detents: [SheetSize.LARGE], showClose: true })
  }

  private canSave() {
    this.allowSave = this.viewModel.canSave();
  }

  // 相对初始快照判断表单是否有未保存改动
  private hasUnsavedChanges(): boolean {
    return JSON.stringify(this.viewModel) !== this.initialViewModelSnapshot;
  }

  // 弹出“放弃改动”二次确认；点击确认执行 onConfirm，点击取消执行 onCancel（停留当前界面）
  private showDiscardConfirm(onConfirm: () => void, onCancel: () => void = () => {}): void {
    this.showConfirm('', $r('app.string.cipher_discard_changes_confirm'), onConfirm, onCancel);
  }

  /**
   * 提交明文表单，由 ViewModel 完成加密与远端创建后再通知密码库刷新
   */
  private async saveCipher() {
    if (this.isSubmitting) {
      return;
    }
    if (!this.allowSave) {
      AppToast.show(this.getUIContext(), $r('app.string.cipher_name_required'));
      return;
    }
    this.isSubmitting = true;
    // 在异步创建开始前标记本地变更，避免后台同步覆盖尚未回写的结果
    VaultChangeNotifier.markLocalChangePending();
    const createdCipher = await this.viewModel.submitCreate();
    this.isSubmitting = false;
    if (createdCipher) {
      AppToast.show(this.getUIContext(), $r('app.string.cipher_create_success'));
      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 1);
      VaultChangeNotifier.setUpdatedCipher(createdCipher);
      DetailRouter.closeDetail();
    } else if (this.viewModel.errorMessage && this.viewModel.errorMessage.length > 0) {
      AppToast.show(this.getUIContext(), this.viewModel.errorMessage === 'cipher_name_required' ?
        $r('app.string.cipher_name_required') : $r('app.string.error_save_failed'));
    }
  }
}
