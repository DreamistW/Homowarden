import { DataPreferences } from '@abner/datastore';
import { IBestDropdownItem, IBestDropdownMenu, IBestRadio, IBestRadioGroup, IBestToast } from '@ibestservices/ibest-ui';
import { EntryRouter } from '../../../../EntryRouter';
import {
  AUTO_LOCK,
  BACKGROUND_TIMESTAMP,
  CardBrandType,
  CipherItemType,
  IdentityTitleType,
  NEED_RELOAD_CIPHERS
} from '../utils/Constants';
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
  @State identityTitle: IdentityTitleType | string = IdentityTitleType.NONE;
  @State cardBrand: CardBrandType | string = CardBrandType.NONE;
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
  itemTypeGroup: string = 'itemTypeSelector';
  identityTitleGroup: string = 'identityTitleSelector';
  cardBrandGroup: string = 'cardBrandSelector';

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          Column() {
            Text('类型')
              .fontSize(14)
              .margin(8)

            IBestRadioGroup({
              group: this.itemTypeGroup,
              active: $cipherType,
              placeDirection: Axis.Horizontal,
              space: 12,
              onChange: () => {
                this.viewModel.type = this.cipherType;
              }
            }) {
              IBestRadio({
                group: this.itemTypeGroup,
                label: '登录',
                name: CipherItemType.LOGIN,
                labelDisabled: true,
              })
              IBestRadio({
                group: this.itemTypeGroup,
                label: '安全笔记',
                name: CipherItemType.NOTE,
                labelDisabled: true,
              })
            }

            Text().margin(8)

            IBestRadioGroup({
              group: this.itemTypeGroup,
              active: $cipherType,
              placeDirection: Axis.Horizontal,
              onChange: () => {
                this.viewModel.type = this.cipherType;
              }
            }) {
              IBestRadio({
                group: this.itemTypeGroup,
                label: '支付卡',
                name: CipherItemType.CARD,
                labelDisabled: true,
              })
              IBestRadio({
                group: this.itemTypeGroup,
                label: '身份',
                name: CipherItemType.IDENTITY,
                labelDisabled: true,
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

          if (this.cipherType == CipherItemType.LOGIN) {
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
          } else if (this.cipherType == CipherItemType.IDENTITY) {
            // 称呼
            Text('称呼')
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            IBestDropdownMenu({ groupId: this.identityTitleGroup }) {
              IBestDropdownItem({
                groupId: this.identityTitleGroup,
                options: this.viewModel.identityTitleOptions,
                value: this.identityTitle,
                onChange: value => {
                  this.identityTitle = value;
                  switch (this.identityTitle) {
                    case IdentityTitleType.NONE:
                      this.viewModel.identityItem.title = '';
                      break;
                    case IdentityTitleType.MR:
                      this.viewModel.identityItem.title = '先生';
                      break;
                    case IdentityTitleType.MRS:
                      this.viewModel.identityItem.title = '女士';
                      break;
                    case IdentityTitleType.MX:
                      this.viewModel.identityItem.title = 'Mx';
                      break;
                    case IdentityTitleType.DR:
                      this.viewModel.identityItem.title = '博士';
                      break;
                    default:
                      this.viewModel.identityItem.title = '';
                  }
                }
              })
            }

            // 名
            Text('名')
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
                this.viewModel.identityItem.firstName = v;
              })
              .margin({ left: 16, right: 16 })
            // 中间名
            Text('中间名')
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
                this.viewModel.identityItem.middleName = v;
              })
              .margin({ left: 16, right: 16 })
            // 姓
            Text('姓')
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
                this.viewModel.identityItem.lastName = v;
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
                this.viewModel.identityItem.username = v;
              })
              .margin({ left: 16, right: 16 })
            // 公司
            Text('公司')
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
                this.viewModel.identityItem.company = v;
              })
              .margin({ left: 16, right: 16 })
            // 社会保障号码
            Text('社会保障号码')
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
                this.viewModel.identityItem.ssn = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.Password)
            // 护照号码
            Text('护照号码')
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
                this.viewModel.identityItem.passportNumber = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.Password)
            // 许可证号码
            Text('许可证号码')
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
                this.viewModel.identityItem.licenseNumber = v;
              })
              .margin({ left: 16, right: 16 })
            // 电子邮箱
            Text('电子邮箱')
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
                this.viewModel.identityItem.email = v;
              })
              .margin({ left: 16, right: 16 })
            // 电话
            Text('电话')
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
                this.viewModel.identityItem.phone = v;
              })
              .margin({ left: 16, right: 16 })
            // 地址1
            Text('地址 1')
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
                this.viewModel.identityItem.address1 = v;
              })
              .margin({ left: 16, right: 16 })
            // 地址2
            Text('地址 2')
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
                this.viewModel.identityItem.address2 = v;
              })
              .margin({ left: 16, right: 16 })
            // 地址3
            Text('地址 3')
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
                this.viewModel.identityItem.address3 = v;
              })
              .margin({ left: 16, right: 16 })
            // 市/镇
            Text('市/镇')
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
                this.viewModel.identityItem.city = v;
              })
              .margin({ left: 16, right: 16 })
            // 州/省
            Text('州/省')
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
                this.viewModel.identityItem.state = v;
              })
              .margin({ left: 16, right: 16 })
            // 邮政编码
            Text('邮政编码')
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
                this.viewModel.identityItem.postalCode = v;
              })
              .margin({ left: 16, right: 16 })
            // 国家
            Text('国家')
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
                this.viewModel.identityItem.country = v;
              })
              .margin({ left: 16, right: 16 })
          } else if (this.cipherType == CipherItemType.CARD) {
            // 姓名
            Text('持卡人姓名')
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
                this.viewModel.cardItem.cardholderName = v;
              })
              .margin({ left: 16, right: 16 })
            // 号码
            Text('号码')
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
                this.viewModel.cardItem.number = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.Password)
            // 品牌
            Text('品牌')
              .fontSize(14)
              .fontColor('#666666')
              .margin({
                left: 16,
                right: 16,
                top: 12,
                bottom: 4
              })
            IBestDropdownMenu({ groupId: this.cardBrandGroup }) {
              IBestDropdownItem({
                groupId: this.cardBrandGroup,
                options: this.viewModel.cardBrandOptions,
                value: this.cardBrand,
                onChange: value => {
                  this.cardBrand = value;
                  switch (this.cardBrand) {
                    case CardBrandType.NONE:
                      this.viewModel.cardItem.brand = '';
                      break;
                    case CardBrandType.VISA:
                      this.viewModel.cardItem.brand = 'Visa';
                      break;
                    case CardBrandType.MASTER:
                      this.viewModel.cardItem.brand = 'MasterCard';
                      break;
                    case CardBrandType.AME:
                      this.viewModel.cardItem.brand = 'American Express';
                      break;
                    case CardBrandType.DISCOVER:
                      this.viewModel.cardItem.brand = 'Discover';
                      break;
                    case CardBrandType.DINERS:
                      this.viewModel.cardItem.brand = 'Diners Club';
                      break;
                    case CardBrandType.JCB:
                      this.viewModel.cardItem.brand = 'JCB';
                      break;
                    case CardBrandType.MAESTRO:
                      this.viewModel.cardItem.brand = 'Maestro';
                      break;
                    case CardBrandType.UNIONPAY:
                      this.viewModel.cardItem.brand = 'UnionPay';
                      break;
                    case CardBrandType.RUPAY:
                      this.viewModel.cardItem.brand = 'RuPay';
                      break;
                    case CardBrandType.OTHER:
                      this.viewModel.cardItem.brand = '其他';
                      break;
                  }
                }
              })
            }

            // 过期月份
            Text('过期月份')
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
                // 校验月份：只允许1-12
                const month = parseInt(v);
                if (v === '' || (!isNaN(month) && month >= 1 && month <= 12)) {
                  this.viewModel.cardItem.expMonth = v;
                }
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.NUMBER_DECIMAL)

            // 过期年份
            Text('过期年份')
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
                // 校验年份：只允许合理的公元年份（1900-9999）
                const year = parseInt(v);
                if (v === '' || (!isNaN(year) && year >= 1900 && year <= 9999)) {
                  this.viewModel.cardItem.expYear = v;
                }
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.NUMBER_DECIMAL)
            // 安全码
            Text('安全码')
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
                this.viewModel.cardItem.code = v;
              })
              .margin({ left: 16, right: 16 })
              .type(InputType.NUMBER_PASSWORD)
          }

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
          TextInput({ text: this.viewModel.notes })
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
    .onHidden(() => {
      DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
    })
    .onShown(() => {
      const autoLockStatus = DataPreferences.getInstance().getSync<number>(AUTO_LOCK);
      if (autoLockStatus == 1) {
        const currentTime = Math.floor(Date.now() / 1000);
        const backgroundTime = DataPreferences.getInstance().getSync<number>(BACKGROUND_TIMESTAMP);
        if (currentTime - backgroundTime > 120) {
          this.pathInfos.pushPath({ name: EntryRouter.UnlockPage });
        }
      }
    })
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
      IBestToast.show("创建成功");
      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 1);
      this.pathInfos.pop();
    }
  }
}