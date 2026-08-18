import { Cipher, CipherDetailMode, CipherDetailParams, CipherField, CipherUri } from '../model/CipherModels';
import {
  CardBrandType,
  CipherFieldType,
  CipherItemType,
  IdentityTitleType,
  NEED_RELOAD_CIPHERS
} from '../utils/Constants';
import { CipherDetailViewModel } from '../viewmodel/CipherDetailViewModel';
import { CipherDetailTextItem } from '../component/CipherDetailTextItem';
import { CipherDetailDropdownItem } from '../component/CipherDetailDropdownItem';
import { TotpDisplayItem } from '../component/TotpDisplayItem';
import { TotpEditItem } from '../component/TotpEditItem';
import { CustomFieldEditItem } from '../component/CustomFieldEditItem';
import { AppDropdown } from '../component/AppDropdown';
import { AppDropdownOption } from '../model/AppUiModels';
import { AppToast } from '../utils/AppToast';
import { Logger } from '@nzy/logger';
import { DataPreferences } from '@abner/datastore';
import { hdsMaterial, HdsNavDestination, HdsNavigationBadgeIconOptions } from '@kit.UIDesignKit';
import { AdaptiveTextButton } from '../component/AdaptiveButton';
import { VaultChangeNotifier } from '../utils/VaultChangeNotifier';
import { AppOptionFactory } from '../localization/AppOptionFactory';
import { CipherDisplayMapping } from '../domain/CipherDisplayMapping';
import { LocaleUtil } from '../localization/LocaleUtil';
import { DeviceUtil } from '../utils/DeviceUtil';
import { DetailRouter } from '../utils/DetailRouter';
import { DetailLeaveGuard, DetailLeaveHandler } from '../utils/DetailLeaveGuard';
import { ConfirmDialog } from '../component/ConfirmDialog';

@Builder
export function CipherDetailPageBuilder() {
  CipherDetailPage();
}

@Component
export struct CipherDetailPage {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  @StorageLink('activeSplitView') isSplitView: boolean = false;
  @State cipher: Cipher = {} as Cipher;
  @State isLoading: boolean = true;
  @State isSaving: boolean = false;
  @State showHideField: boolean = false;
  @State isEditable: boolean = false;
  @State isDetailLoaded: boolean = false;
  @State selectedCardBrand: CardBrandType = CardBrandType.NONE;
  @State selectedIdentityTitle: IdentityTitleType = IdentityTitleType.NONE;
  @State editUris: CipherUri[] = [] as CipherUri[];
  @State totpSecret: string = '';
  @State showTotpSecret: boolean = false;
  @State formattedCreationDate: string = '';
  @State formattedRevisionDate: string = '';
  @State formattedDeletedDate: string = '';
  @State newFieldEditType: CipherFieldType = CipherFieldType.TEXT;
  pathInfos: NavPathStack = new NavPathStack();
  private viewModel: CipherDetailViewModel = new CipherDetailViewModel();
  private initialMode: CipherDetailMode = CipherDetailMode.VIEW;
  // 进入编辑模式时的明文快照，用于判断是否有未保存改动。
  private originalCipherSnapshot: string = '';
  private identityTitleGroup: string = 'identityTitleSelector';
  private cardBrandGroup: string = 'cardBrandSelector';
  // 下拉菜单选项
  private identityTitleOptions: AppDropdownOption[] = AppOptionFactory.identityTitles();
  private cardBrandOptions: AppDropdownOption[] = AppOptionFactory.cardBrands();
  private leaveHandler: DetailLeaveHandler = (onLeave: () => void, onStay: () => void): void => {
    if (!this.isEditable) {
      onLeave();
      return;
    }
    if (this.hasUnsavedChanges()) {
      this.showDiscardConfirm(() => {
        // exitEditMode 会置 isEditable=false 并 loadCipherDetail 还原成修改前内容，
        // 不能只改 isEditable，否则页面仍显示编辑后的值。
        this.exitEditMode();
        onLeave();
      }, onStay);
      return;
    }
    this.exitEditMode();
    onLeave();
  };

  aboutToDisappear(): void {
    DetailLeaveGuard.unregister(this.leaveHandler);
    // 旋转跨栈迁移会销毁本页，随之关闭未决确认框（等同取消）。
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

  private showConfirm(title: ResourceStr, message: ResourceStr, action: () => Promise<boolean>,
    cancel: () => void = () => {}, confirmText: ResourceStr = $r('app.string.common_confirm')): void {
    this.confirmTitle = title;
    this.confirmMessage = message;
    this.confirmText = confirmText;
    this.confirmAction = action;
    this.confirmCancel = cancel;
    this.confirmController.open();
  }

  private handleLocaleRevision(): void {
    this.identityTitleOptions = AppOptionFactory.identityTitles();
    this.cardBrandOptions = AppOptionFactory.cardBrands();
    this.refreshFormattedDates();
  }

  private refreshFormattedDates(): void {
    this.formattedCreationDate = LocaleUtil.formatDateTime(this.cipher.creationDate);
    this.formattedRevisionDate = LocaleUtil.formatDateTime(this.cipher.revisionDate);
    this.formattedDeletedDate = LocaleUtil.formatDateTime(this.cipher.deletedDate);
  }

  // 将身份标题文本转换为枚举值
  private getIdentityTitleEnum(title: string | null | undefined): IdentityTitleType {
    return CipherDisplayMapping.readIdentityTitle(title).type;
  }

  // 将卡品牌文本转换为枚举值
  private getCardBrandEnum(brand: string | null | undefined): CardBrandType {
    return CipherDisplayMapping.readCardBrand(brand).type;
  }

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

  EditItemBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_edit'),
      icon: $r('app.media.icon_edit'),
      action: () => {
        this.enterEditMode();
      }
    }
  }
  DeleteItemBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_delete'),
      icon: $r('app.media.icon_delete'),
      action: () => {
        this.deleteCipher();
      }
    }
  }
  ConfirmEditBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_confirm'),
      icon: $r('app.media.icon_confirm'),
      action: async () => {
        if (this.isSaving) {
          return;
        }
        await this.saveCipher();
      }
    }
  }
  CancelEditBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_cancel'),
      icon: $r('app.media.icon_cancel'),
      action: () => {
        if (this.isSaving) {
          return;
        }
        this.requestCancelEdit();
      }
    }
  }
  RestoreItemBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_restore'),
      icon: $r('app.media.icon_restore'),
      action: async () => {
        await this.restoreCipher();
      }
    }
  }

  /**
   * 加载密码项详情
   */
  private async loadCipherDetail() {
    this.isLoading = true;
    this.isDetailLoaded = false;
    try {
      // cipher 初始值是列表精简模型，详情加载完成后才替换为可编辑的完整明文数据。
      const cipherDetail = await this.viewModel.getCipherDetail(this.cipher);
      if (cipherDetail) {
        this.cipher = cipherDetail;
        this.refreshFormattedDates();
        if (this.cipher.type === CipherItemType.LOGIN && this.cipher.login) {
          this.editUris = this.cipher.login.uris;
        }
        // 初始化下拉菜单的选中值
        if (this.cipher.card?.brand) {
          this.selectedCardBrand = this.getCardBrandEnum(this.cipher.card.brand);
        }
        if (this.cipher.identity?.title) {
          this.selectedIdentityTitle = this.getIdentityTitleEnum(this.cipher.identity.title);
        }
        // 初始化TOTP密钥
        if (this.cipher.login?.totp) {
          this.totpSecret = this.cipher.login.totp;
        } else {
          this.totpSecret = '';
        }
        this.isDetailLoaded = true;
        if (this.initialMode === CipherDetailMode.EDIT) {
          this.initialMode = CipherDetailMode.VIEW;
          this.enterEditMode();
        }
      }
    } catch (error) {
      Logger.error('Failed to load cipher detail:', error);
      this.isEditable = false;
      AppToast.show(this.getUIContext(), $r('app.string.error_load_failed'));
    } finally {
      this.isLoading = false;
    }
  }

  private enterEditMode(): void {
    if (!this.isDetailLoaded || !this.cipher.edit || this.cipher.deletedDate) {
      AppToast.show(this.getUIContext(), $r('app.string.error_encryption'));
      return;
    }
    this.originalCipherSnapshot = JSON.stringify(this.cipher);
    this.isEditable = true;
  }

  // 退出编辑模式并重新加载详情。
  private exitEditMode(): void {
    this.isEditable = false;
    // getCipherDetail 基于传入对象原地刷新 login/fields 等嵌套字段，但不会回滚 name/notes
    // 等标量；先从进入编辑时的快照整体还原 this.cipher，再加载详情，确保完全回到修改前。
    if (this.originalCipherSnapshot) {
      this.cipher = JSON.parse(this.originalCipherSnapshot) as Cipher;
    }
    this.loadCipherDetail();
  }

  // 取消编辑：若有未保存改动则二次确认，确认后放弃改动退出编辑。
  private requestCancelEdit(): void {
    if (this.hasUnsavedChanges()) {
      this.showDiscardConfirm(() => {
        this.exitEditMode();
      });
    } else {
      this.exitEditMode();
    }
  }

  // 编辑模式下相对快照判断是否有未保存改动。
  private hasUnsavedChanges(): boolean {
    return this.isEditable && JSON.stringify(this.cipher) !== this.originalCipherSnapshot;
  }

  // 弹出“放弃改动”二次确认；点击确认执行 onConfirm，点击取消执行 onCancel（停留当前界面）。
  private showDiscardConfirm(onConfirm: () => void, onCancel: () => void = () => {}): void {
    this.showConfirm('', $r('app.string.cipher_discard_changes_confirm'), async (): Promise<boolean> => {
      onConfirm();
      return true;
    }, onCancel);
  }

  /**
   * 保存密码项
   */
  private async saveCipher() {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    try {
      if (this.cipher.type === CipherItemType.LOGIN && this.cipher.login) {
        // 过滤掉 uri 字段为空的元素
        const filteredUris = this.editUris.filter(uri => uri.uri && uri.uri.trim() !== '');
        this.cipher.login.uris = filteredUris;
      }

      // ViewModel 在内部完成明文到密文的转换，页面对象仍保持明文供后续展示。
      VaultChangeNotifier.markLocalChangePending();
      this.cipher = await this.viewModel.updateCipher(this.cipher);
      // 保存成功，退出编辑模式
      this.isEditable = false;
      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 1);
      VaultChangeNotifier.setUpdatedCipher(this.cipher);
      AppToast.show(this.getUIContext(), $r('app.string.common_success'));
      // 重新加载密码项
      await this.loadCipherDetail();
    } catch (error) {
      Logger.error('Failed to save cipher:', error);
      AppToast.show(this.getUIContext(), $r('app.string.error_save_failed'));
    } finally {
      this.isSaving = false;
    }
  }

  private getConfirmEditBtn(): HdsNavigationBadgeIconOptions {
    return {
      content: {
        label: this.isSaving ? $r('app.string.common_saving') : $r('app.string.common_confirm'),
        icon: $r('app.media.icon_confirm'),
        action: async () => {
          if (this.isSaving) {
            return;
          }
          await this.saveCipher();
        }
      }
    };
  }

  private getTitleMenu(): HdsNavigationBadgeIconOptions[] {
    if (this.isEditable) {
      return [this.CancelEditBtn, this.getConfirmEditBtn()];
    }
    if (this.cipher.deletedDate) {
      return [this.RestoreItemBtn, this.DeleteItemBtn];
    }
    if (!this.isDetailLoaded) {
      return [this.DeleteItemBtn];
    }
    return [this.EditItemBtn, this.DeleteItemBtn];
  }

  /**
   * 还原密码项
   */
  private async restoreCipher() {
    try {
      VaultChangeNotifier.markLocalChangePending();
      this.cipher = await this.viewModel.restoreCipher(this.cipher);
      this.refreshFormattedDates();
      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 1);
      VaultChangeNotifier.setUpdatedCipher(this.cipher);
      // 显示成功提示
      AppToast.show(this.getUIContext(), $r('app.string.common_success'));
    } catch (error) {
      Logger.error('Failed to restore cipher:', error);
      AppToast.show(this.getUIContext(), $r('app.string.error_save_failed'));
    }
  }

  /**
   * 添加网站输入框
   */
  private addUriEdit() {
    if (this.cipher.login?.uris) {
      const tempUri: CipherUri = {
        uri: "",
        uriChecksum: ""
      };
      this.editUris.push(tempUri);
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
            Text($r('app.string.common_loading'))
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
              // Text(this.cipher.name)
              //   .fontSize(16)
              //   .fontWeight(FontWeight.Bold)
              //   .margin({ top: 8, bottom: 8 })

              Row() {
                // 项目名称
                CipherDetailTextItem({
                  label: $r('app.string.cipher_item_name'),
                  content: this.cipher.name,
                  isEditable: this.isEditable,
                  showCopyButton: false,
                  onValueChange: (value: string) => {
                    this.cipher.name = value;
                  }
                })
              }
              .margin({ top: 8, bottom: 8 })
              .width('100%')
              .padding(16)

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

              // 自定义字段：查看模式下仅当存在字段时才渲章节；编辑模式下必须显示以容纳"添加字段"入口。
              if (this.isEditable || (this.cipher.fields && this.cipher.fields.length > 0)) {
                this.buildCustomFieldsSection();
              }

              // 备注
              Column() {
                Text($r('app.string.cipher_notes'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 12 })

                if (this.isEditable) {
                  TextInput({ text: this.cipher.notes })
                    .accessibilityText($r('app.string.cipher_notes'))
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
                Row({ space: 8 }) {
                  Checkbox({ name: 'reprompt', group: 'cipher' })
                    .accessibilityText($r('app.string.cipher_reprompt'))
                    .select(this.cipher.reprompt === 1)
                    .onChange((checked: boolean) => {
                      this.cipher.reprompt = checked ? 1 : 0;
                    })
                  Text($r('app.string.cipher_reprompt'))
                }
              }

              // 元数据
              Column() {
                Text($r('app.string.cipher_metadata'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 12 })

                Row() {
                  Text($r('app.string.cipher_created'))
                    .fontSize(14)
                    .fontColor('#666666')
                    .width(80)

                  Text(this.formattedCreationDate)
                    .fontSize(14)
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })

                Row() {
                  Text($r('app.string.cipher_modified'))
                    .fontSize(14)
                    .fontColor('#666666')
                    .width(80)

                  Text(this.formattedRevisionDate)
                    .fontSize(14)
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })

                if (this.cipher.deletedDate) {
                  Row() {
                    Text($r('app.string.cipher_deleted'))
                      .fontSize(14)
                      .fontColor('#666666')
                      .width(80)

                    Text(this.formattedDeletedDate)
                      .fontSize(14)
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                }
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
    .titleBar({
      content: {
        title: {
          mainTitle: $r('app.string.cipher_detail_title')
        },
        menu: {
          value: this.getTitleMenu()
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
      // NavDestination 就绪后才能取得当前页面栈和调用方传入的密钥上下文。
      this.pathInfos = ctx.pathStack;
      const param = ctx.pathInfo.param as CipherDetailParams;
      if (param.cipher && param.cipher.id) {
        // 深拷贝：避免编辑 this.cipher 时污染 param.cipher（同一引用会连累列表数据，
        // 且旋转跨栈迁移重建时新实例会读到被改过的 param，显示修改后内容）。
        this.cipher = JSON.parse(JSON.stringify(param.cipher)) as Cipher;
        this.viewModel.symmetricKey = param.symmetricKey;
        this.initialMode = param.initialMode ?? CipherDetailMode.VIEW;
        void this.loadCipherDetail();
      }
      DetailLeaveGuard.register(this.leaveHandler);
    })
    .onBackPressed((): boolean => {
      if (this.isEditable) {
        // 编辑模式下按返回退回查看模式（若有改动则二次确认），而非直接离开页面。
        this.requestCancelEdit();
        return true;
      }
      if (this.pathInfos.getAllPathName().length > 0) {
        DetailRouter.closeDetail();
        return true;
      }
      return false;
    })
  }

  @Builder
  buildLoginSection() {
    Column() {
      Text($r('app.string.cipher_login_info'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // 用户名
      CipherDetailTextItem({
        label: $r('app.string.cipher_username'),
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
        label: $r('app.string.cipher_password'),
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
      if (this.cipher.login?.uris && this.cipher.login.uris.length > 0 && !this.isEditable) {
        ForEach(this.editUris, (uri: CipherUri, index: number) => {
          CipherDetailTextItem({
            label: $r('app.string.cipher_website'),
            content: uri.uri,
            isEditable: this.isEditable,
            isUri: true,
            onValueChange: (value: string) => {
              uri.uri = value;
            }
          })
        })
      }

      if (this.isEditable) {
        ForEach(this.editUris, (uri: CipherUri) => {
          CipherDetailTextItem({
            label: $r('app.string.cipher_website'),
            content: uri.uri,
            isEditable: this.isEditable,
            isUri: true,
            onValueChange: (value: string) => {
              uri.uri = value;
            }
          })
        })

        Row() {
          AdaptiveTextButton({
            text: $r('app.string.cipher_add_website'),
            barWidth: 150,
            barHeight: 50,
            fontSize: 18,
            onButtonClick: () => {
              this.addUriEdit();
            }
          })
        }

        // Button() {
        //   Text('添加网站')
        //     .fontSize(18)
        //     .fontColor(Color.White)
        // }
        // .width(150)
        // .height(40)
        // .backgroundColor('#007DFF')
        // .borderRadius(25)
        // .margin({ top: 24, bottom: 24 })
        // .onClick(() => {
        //   this.addUriEdit();
        // })
      }

      // TOTP验证码显示（仅查看模式且有TOTP密钥时）
      if (!this.isEditable && this.cipher.login?.totp) {
        TotpDisplayItem({
          secret: this.cipher.login.totp
        })
      }

      // TOTP密钥编辑（编辑模式）
      if (this.isEditable) {
        TotpEditItem({
          totpSecret: $totpSecret,
          onSecretChange: (value: string) => {
            if (this.cipher.login) {
              this.cipher.login.totp = value;
            }
          }
        })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  @Builder
  buildCardSection() {
    Column() {
      Text($r('app.string.cipher_card_info'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // 持卡人姓名
      CipherDetailTextItem({
        label: $r('app.string.cipher_cardholder'),
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
        label: $r('app.string.cipher_number'),
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
        label: $r('app.string.cipher_brand'),
        content: CipherDisplayMapping.cardBrandLabel(this.cipher.card?.brand),
        dropdownOptions: this.cardBrandOptions,
        groupId: this.cardBrandGroup,
        selectedValue: this.selectedCardBrand,
        onValueChange: (value: number) => {
          this.selectedCardBrand = this.cardBrandFromValue(value);
          if (this.cipher.card) {
            this.cipher.card.brand = CipherDisplayMapping.writeCardBrand(this.selectedCardBrand);
          }
        },
        isEditable: this.isEditable
      })

      // 过期月份
      CipherDetailTextItem({
        label: $r('app.string.cipher_exp_month'),
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
        label: $r('app.string.cipher_exp_year'),
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
        label: $r('app.string.cipher_security_code'),
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
      Text($r('app.string.vault_type_identity'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      // 称呼
      CipherDetailDropdownItem({
        label: $r('app.string.cipher_identity_title'),
        content: CipherDisplayMapping.identityTitleLabel(this.cipher.identity?.title),
        dropdownOptions: this.identityTitleOptions,
        groupId: this.identityTitleGroup,
        selectedValue: this.selectedIdentityTitle,
        onValueChange: (value: number) => {
          this.selectedIdentityTitle = this.identityTitleFromValue(value);
          if (this.cipher.identity) {
            this.cipher.identity.title = CipherDisplayMapping.writeIdentityTitle(this.selectedIdentityTitle);
          }
        },
        isEditable: this.isEditable
      })

      // 名
      CipherDetailTextItem({
        label: $r('app.string.cipher_first_name'),
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
        label: $r('app.string.cipher_middle_name'),
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
        label: $r('app.string.cipher_last_name'),
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
        label: $r('app.string.cipher_username'),
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
        label: $r('app.string.cipher_company'),
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
        label: $r('app.string.cipher_ssn'),
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
        label: $r('app.string.cipher_passport'),
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
        label: $r('app.string.cipher_license'),
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
        label: $r('app.string.cipher_email'),
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
        label: $r('app.string.cipher_phone'),
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
        label: $r('app.string.cipher_address1'),
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
        label: $r('app.string.cipher_address2'),
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
        label: $r('app.string.cipher_address3'),
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
        label: $r('app.string.cipher_city'),
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
        label: $r('app.string.cipher_state'),
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
        label: $r('app.string.cipher_postal_code'),
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
        label: $r('app.string.cipher_country'),
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
      Text($r('app.string.vault_type_note'))
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
      Text($r('app.string.cipher_custom_fields'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })

      if (this.isEditable) {
        // 编辑模式：可增删改；每个 row 通过回调就地修改字段并整组重新赋值触发 ForEach 重渲。
        ForEach(this.cipher.fields ?? [], (field: CipherField) => {
          CustomFieldEditItem({
            field: field,
            onNameChange: (v: string) => {
              field.name = v;
              this.cipher.fields = [...(this.cipher.fields ?? [])];
            },
            onValueChange: (v: string) => {
              field.value = v;
              this.cipher.fields = [...(this.cipher.fields ?? [])];
            },
            onBoolChange: (v: boolean) => {
              field.value = v ? 'true' : 'false';
              this.cipher.fields = [...(this.cipher.fields ?? [])];
            },
            onRemove: () => {
              this.cipher.fields = (this.cipher.fields ?? []).filter(f => f !== field);
            }
          })
        }, (field: CipherField) => field.itemId ?? field.name)

        // 类型下拉 + 添加按钮
        Row({ space: 8 }) {
          AppDropdown({
            options: AppOptionFactory.customFieldTypes(),
            value: this.newFieldEditType,
            accessibilityLabel: $r('app.string.cipher_field_type'),
            onChange: (value: number) => {
              this.newFieldEditType = this.customFieldTypeFromValue(value);
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
              const newField: CipherField = {
                name: '',
                value: this.newFieldEditType === CipherFieldType.BOOL ? 'false' : '',
                type: this.newFieldEditType,
                itemId: DeviceUtil.generateUUID()
              };
              this.cipher.fields = [...(this.cipher.fields ?? []), newField];
            }
          })
        }
        .margin({ top: 8 })
      } else {
        // 查看模式：沿用现有只读 CipherDetailTextItem 渲染。
        ForEach(this.cipher.fields as CipherField[], (field: CipherField) => {
          CipherDetailTextItem({
            label: field.name,
            content: this.getFieldValue(field),
            showContent: (field.type == CipherFieldType.HIDE) ? this.showHideField : true,
            showHideButton: (field.type == CipherFieldType.HIDE) ? true : false,
            isEditable: false
          })
        }, (field: CipherField) => field.itemId ?? field.name)
      }
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 8 })
  }

  private deleteCipher() {
    // 与生成器/分享历史一致，使用可关闭的 ConfirmDialog 二次确认。
    const message: ResourceStr = this.cipher.deletedDate
      ? $r('app.string.cipher_delete_forever_confirm', this.cipher.name)
      : $r('app.string.cipher_move_trash_confirm', this.cipher.name);
    this.showConfirm($r('app.string.cipher_delete_title'), message, async (): Promise<boolean> => {
      return await this.doDeleteCipher();
    });
  }

  /**
   * 执行删除密码项
   */
  private async doDeleteCipher(): Promise<boolean> {
    try {
      // 已在回收站中的条目再次删除时才执行永久删除。
      const isRealDelete = this.cipher.deletedDate ? true : false;
      VaultChangeNotifier.markLocalChangePending();
      const changedCipher = await this.viewModel.deleteCipher(this.cipher, isRealDelete);
      Logger.info(`Cipher ${this.cipher.id} deleted successfully`);

      // 显示成功提示
      AppToast.show(this.getUIContext(), $r('app.string.common_delete_success'));

      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 1);
      if (changedCipher) {
        VaultChangeNotifier.setUpdatedCipher(changedCipher);
      } else {
        VaultChangeNotifier.setDeletedCipher(this.cipher.id);
      }

      DetailRouter.closeDetail();
      return true;
    } catch (error) {
      Logger.error('Failed to delete cipher:', error);

      // 显示失败提示
      AppToast.show(this.getUIContext(), $r('app.string.error_delete_failed'));

      return false;
    }
  }

  private getFieldValue(field: CipherField): string {
    let returnStr: string = '';
    if (field.type == CipherFieldType.BOOL) {
      returnStr = field.value == 'true' ?
        (this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.common_yes')) ?? '') :
        (this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.common_no')) ?? '');
    } else {
      returnStr = field.value;
    }
    return returnStr;
  }
}
