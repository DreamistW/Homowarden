import { EntryRouter } from '../../../../EntryRouter';
import { Cipher, CipherDetailMode, CipherDetailParams, CipherIdentity } from '../model/CipherModels';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { common, Want } from '@kit.AbilityKit';
import { AppToast } from '../utils/AppToast';
import { AppDropdown } from '../component/AppDropdown';
import { FormDialog } from '../component/FormDialog';
import { ConfirmDialog } from '../component/ConfirmDialog';
import { DataPreferences } from '@abner/datastore';
import {
  CipherItemType, FilterType, LOGIN_STATUS_KEY, NEED_RELOAD_CIPHERS
} from '../utils/Constants';
import { CipherCopyField, CipherItem } from '../component/CipherItem';
import {
  HdsNavDestination, HdsNavigationBadgeIconOptions
} from '@hms.hds.hdsBaseComponent';
import { hdsMaterial } from '@kit.UIDesignKit';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { VaultChangeNotifier, VaultLocalChange, VaultLocalChangeType } from '../utils/VaultChangeNotifier';
import { MainBottomNavigation } from '../component/MainBottomNavigation';
import { MainTab } from '../component/MainNavigationItems';
import { TotpListPage } from './TotpListPage';
import { Sure2SharePage } from './Sure2Share';
import { SettingsPage } from './SettingsPage';
import { GeneratorPage } from './GeneratorPage';
import { AppText, AppTextKey } from '../localization/AppText';
import { AppTextResolver } from '../localization/AppTextResolver';
import { AdaptiveIconButton } from '../component/AdaptiveButton';
import { AppDropdownOption } from '../model/AppUiModels';
import { AppOptionFactory } from '../localization/AppOptionFactory';
import { DetailRouter } from '../utils/DetailRouter';
import { MainSideRail } from '../component/MainSideRail';
import { AdaptiveShell } from '../component/AdaptiveShell';
import { DetailLeaveGuard } from '../utils/DetailLeaveGuard';
import { CipherDetailViewModel } from '../viewmodel/CipherDetailViewModel';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';
import { TOTPUtil } from '../utils/TOTPUtil';
import { promptAction } from '@kit.ArkUI';
import { FormFactorUtil } from '../utils/FormFactorUtil';

@Builder
export function VaultPageBuilder() {
  VaultPage();
}

class QuickActionMenuButton implements promptAction.Button {
  text: string;
  color: string = '#0A59F7';

  constructor(text: string) {
    this.text = text;
  }
}

@Component
struct VaultContent {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  @StorageLink('vaultCommittedChangeRevision') @Watch('handleCommittedChange') committedChangeRevision: number = 0;
  @Prop @Watch('handleActivationRevision') activationRevision: number = 0;
  @Prop @Watch('handleManualRefreshRevision') manualRefreshRevision: number = 0;
  @Prop pullToRefreshEnabled: boolean = true;
  onVaultDataChanged: (ciphers: Cipher[], symmetricKey: string) => void = () => {};
  onNavigateToDetail: (params: CipherDetailParams) => void = () => {};
  onRelogin: () => void = () => {};
  @State viewModel: VaultViewModel = new VaultViewModel();
  private listScroller: ListScroller = new ListScroller();
  @State searchText: string = '';
  @State selectedType: FilterType = FilterType.ALL;
  @State filterOptions: AppDropdownOption[] = AppOptionFactory.vaultFilters(0, 0, 0, 0, 0, 0, 0);
  @State displayCiphers: Cipher[] = [];
  @State isInitialLoading: boolean = true;
  @State isLoading: boolean = false;
  @State passwordInput: string = '';
  @State passwordError: ResourceStr = '';
  groupId: string = 'filter_menu';
  private needReLogin: boolean = false;
  private pendingProtectedAction: (() => void) | null = null;
  private isQuickActionLoading: boolean = false;
  private passwordDialogController: CustomDialogController = new CustomDialogController({
    builder: FormDialog({
      title: $r('app.string.totp_master_title'),
      contentBuilder: (): void => this.masterPasswordContent(),
      cancel: () => {
        this.pendingProtectedAction = null;
      },
      confirm: async (): Promise<void> => {
        await this.confirmMasterPassword();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  });
  @State reloginTitle: ResourceStr = $r('app.string.vault_relogin_title');
  @State reloginMessage: ResourceStr = $r('app.string.vault_relogin_message');
  @State reloginConfirmText: ResourceStr = $r('app.string.common_confirm');
  private isReloginDialogOpen: boolean = false;
  private reloginDialogController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: $reloginTitle,
      message: $reloginMessage,
      confirmText: $reloginConfirmText,
      showCancel: false,
      onConfirm: async (): Promise<boolean> => {
        this.isReloginDialogOpen = false;
        DataPreferences.getInstance().putSync(LOGIN_STATUS_KEY, 0);
        void WindowPrivacyUtil.applyForCurrentState();
        this.onRelogin();
        return true;
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  async aboutToAppear(): Promise<void> {
    await this.loadCiphersWithBackgroundSync();
    this.consumeCommittedChange();
  }

  aboutToDisappear(): void {
    this.isReloginDialogOpen = false;
    this.pendingProtectedAction = null;
    this.reloginDialogController.close();
    this.passwordDialogController.close();
  }

  private handleActivationRevision(): void {
    this.consumeCommittedChange();
  }

  private handleManualRefreshRevision(): void {
    if (!this.isLoading) {
      void this.loadCiphers(true);
    }
  }

  private handleCommittedChange(): void {
    // 分栏下列表始终挂载，直接消费提交事件而不依赖页面重新激活。
    this.consumeCommittedChange();
  }

  private consumeCommittedChange(): void {
    const change = VaultChangeNotifier.consumeChange();
    const needReload = DataPreferences.getInstance().getSync<number>(NEED_RELOAD_CIPHERS) === 1;
    if (!change && !needReload) {
      return;
    }
    DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 0);
    void this.handleLocalVaultChange(change);
  }

  private handleLocaleRevision(): void {
    // 语言变化后重排身份姓名并重建带数量的筛选文案。
    this.viewModel.refreshLocale();
    this.refreshFilterOptions();
    this.applyCurrentFilter();
    this.publishVaultData();
  }

  private publishVaultData(): void {
    this.onVaultDataChanged(this.viewModel.allCiphers, this.viewModel.symmetricKey);
  }

  private refreshFilterOptions(): void {
    this.filterOptions = this.viewModel.filterOptions.slice();
  }

  private applyCurrentFilter(): void {
    this.viewModel.filterCiphers(this.selectedType, this.searchText);
    this.displayCiphers = this.viewModel.filteredCiphers.slice();
  }

  /** 优先展示本地数据，并按是否为空选择前台或后台同步策略。 */
  private async loadCiphersWithBackgroundSync() {
    // 设置重新登录回调
    this.viewModel.onReLoginRequired = () => {
      this.needReLogin = true;
      this.showReloginDialog();
    };

    this.isInitialLoading = true;
    try {
      // 第一步：先加载本地数据库
      const localResult = await this.viewModel.loadCiphers(false);
      if (!localResult) {
        AppToast.show(this.getUIContext(), $r('app.string.error_load_failed'));
      }

      this.applyCurrentFilter();
      this.refreshFilterOptions();
      this.publishVaultData();

      this.isInitialLoading = false;
      void this.doBackgroundSync();
    } finally {
      this.isInitialLoading = false;
    }
  }

  /** 静默同步服务器数据，并丢弃本地编辑发生前启动的过期结果。 */
  private async doBackgroundSync() {
    const changeRevision = VaultChangeNotifier.getChangeRevision();
    const result = await this.viewModel.syncCiphersInBackground(() => {
      return changeRevision === VaultChangeNotifier.getChangeRevision();
    });

    if (result) {
      // 后台同步完成后，重新应用当前筛选条件
      this.applyCurrentFilter();
      this.refreshFilterOptions();
      this.publishVaultData();
    } else {
      // 后台同步失败时，不影响已显示的本地数据
      if (!this.needReLogin && this.viewModel.errorMessage) {
        AppToast.show(this.getUIContext(), $r('app.string.vault_sync_failed_local'));
      }
    }
  }

  private async reloadCiphersAfterLocalChange() {
    const localResult = await this.viewModel.loadCiphers(false);
    if (localResult) {
      this.applyCurrentFilter();
      this.refreshFilterOptions();
      this.publishVaultData();
    } else {
      AppToast.show(this.getUIContext(), $r('app.string.error_load_failed'));
    }
    void this.doBackgroundSync();
  }

  private async handleLocalVaultChange(change: VaultLocalChange | null): Promise<void> {
    // 先更新内存列表保证返回页面即时可见，再以数据库和后台同步结果校准。
    if (change?.type === VaultLocalChangeType.UPSERT && change.cipher) {
      this.viewModel.applyLocalCipherChange(change.cipher, this.selectedType, this.searchText);
      this.applyCurrentFilter();
      this.refreshFilterOptions();
      this.publishVaultData();
      void this.reloadCiphersAfterLocalChange();
      return;
    }

    if (change?.type === VaultLocalChangeType.DELETE && change.cipherId) {
      this.viewModel.applyLocalCipherDeletion(change.cipherId, this.selectedType, this.searchText);
      this.applyCurrentFilter();
      this.refreshFilterOptions();
      this.publishVaultData();
      void this.reloadCiphersAfterLocalChange();
      return;
    }

    await this.reloadCiphersAfterLocalChange();
  }

  private async loadCiphers(forceSync: boolean = true): Promise<void> {
    this.viewModel.onReLoginRequired = () => {
      this.needReLogin = true;
      this.showReloginDialog();
    };

    this.isLoading = true;
    try {
      const result = await this.viewModel.loadCiphers(forceSync);
      if (result) {
        AppToast.show(this.getUIContext(), $r('app.string.vault_refresh_success'));
      } else if (this.viewModel.errorDetail.length > 0) {
        AppToast.show(this.getUIContext(), this.viewModel.errorDetail);
      } else if (this.viewModel.errorMessage !== undefined) {
        AppToast.show(this.getUIContext(), AppTextResolver.resource(this.viewModel.errorMessage));
      } else {
        AppToast.show(this.getUIContext(), $r('app.string.vault_refresh_failed'));
      }
      this.applyCurrentFilter();
      this.refreshFilterOptions();
      this.publishVaultData();
    } catch (error) {
      AppToast.show(this.getUIContext(), $r('app.string.vault_refresh_failed'));
    } finally {
      this.isLoading = false;
    }
  }

  // 后台同步判定会话失效时，用 ConfirmDialog 提示重新登录（无取消按钮，只能确认）。
  private showReloginDialog(): void {
    if (this.isReloginDialogOpen) {
      return;
    }
    this.isReloginDialogOpen = true;
    this.reloginDialogController.open();
  }

  @Builder
  loadingContent() {
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
  }

  @Builder
  emptyContent() {
    Column() {
      Text($r('app.string.vault_empty'))
        .fontSize(16)
        .fontColor(Color.Gray)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  refreshContent() {
    Row({ space: 8 }) {
      LoadingProgress()
        .width(24)
        .height(24)
      if (this.isLoading) {
        Text($r('app.string.common_refreshing'))
          .fontSize(14)
          .fontColor(Color.Gray)
      } else {
        Text($r('app.string.common_pull_to_refresh'))
          .fontSize(14)
          .fontColor(Color.Gray)
      }
    }
    .width('100%')
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  listContent() {
    if (this.isLoading) {
      this.loadingContent()
    } else {
      List({ scroller: this.listScroller }) {
        if (this.displayCiphers.length === 0) {
          ListItem() {
            this.emptyContent()
          }
        } else {
          ForEach(this.displayCiphers, (cipher: Cipher) => {
            ListItem() {
              CipherItem({
                cipher: cipher,
                onTap: () => {
                  this.navigateToDetail(cipher);
                },
                onCopyField: (field: CipherCopyField) => {
                  this.requestProtectedAction(cipher, () => {
                    void this.copyCipherField(cipher, field);
                  });
                },
                onEdit: () => {
                  this.navigateToEdit(cipher);
                },
                onOpenUrl: () => {
                  this.requestProtectedAction(cipher, () => {
                    void this.openCipherUrl(cipher);
                  });
                }
              })
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .edgeEffect(EdgeEffect.None)
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          if (this.isInitialLoading) {
            this.loadingContent()
          } else {
            // 搜索栏
            Row({ space: 8 }) {
              Column() {
                AppDropdown({
                  options: this.filterOptions,
                  value: this.selectedType,
                  optionFontSize: 12,
                  accessibilityLabel: $r('app.string.vault_title'),
                  onChange: (value: number) => {
                    this.selectedType = value;
                    this.applyCurrentFilter();
                  }
                })
              }.width('36%')

              Search({
                value: this.searchText,
                placeholder: $r('app.string.vault_search_placeholder'),
              })
                .onChange((value: string) => {
                  this.searchText = value;
                  this.applyCurrentFilter();
                }
              ).layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })

            if (this.pullToRefreshEnabled) {
              Refresh({ refreshing: this.isLoading, builder: this.refreshContent() }) {
                this.listContent()
              }
              .onRefreshing(() => {
                if (!this.isLoading) {
                  void this.loadCiphers(true);
                }
              })
              .width('100%')
              .layoutWeight(1)
            } else {
              Column() {
                this.listContent()
              }
              .width('100%')
              .layoutWeight(1)
            }
          }

        }
        .width('100%')
        .height('100%')

      }
      .width('100%')
      .height('100%')
    }

  private navigateToDetail(cipher: Cipher): void {
    this.requestProtectedAction(cipher, () => {
      this.doNavigateToDetail(cipher, CipherDetailMode.VIEW);
    });
  }

  private navigateToEdit(cipher: Cipher): void {
    this.requestProtectedAction(cipher, () => {
      this.doNavigateToDetail(cipher, CipherDetailMode.EDIT);
    });
  }

  private requestProtectedAction(cipher: Cipher, action: () => void): void {
    if (cipher.reprompt !== 1) {
      action();
      return;
    }
    this.pendingProtectedAction = action;
    this.passwordInput = '';
    this.passwordError = '';
    this.passwordDialogController.open();
  }

  private doNavigateToDetail(cipher: Cipher, initialMode: CipherDetailMode): void {
    const params: CipherDetailParams = {
      cipher: cipher,
      symmetricKey: this.viewModel.symmetricKey,
      initialMode: initialMode
    };
    this.onNavigateToDetail(params);
  }

  // 密码验证弹框点击确认时调用：校验通过则跳转详情并关闭弹框，否则回填错误文案并保持打开。
  private async confirmMasterPassword(): Promise<void> {
    const result = await this.verifyMasterPassword();
    if (result) {
      const action = this.pendingProtectedAction;
      this.pendingProtectedAction = null;
      this.passwordDialogController.close();
      action?.();
    }
  }

  @Builder
  masterPasswordContent() {
    Column() {
      Text($r('app.string.totp_master_prompt'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })
      TextInput({ placeholder: $r('app.string.unlock_enter_master_password'), text: this.passwordInput })
        .accessibilityText($r('app.string.unlock_enter_master_password'))
        .type(InputType.Password)
        .onChange((value: string) => {
          this.passwordInput = value;
          this.passwordError = '';
        })
      if (this.passwordError) {
        Text(this.passwordError)
          .fontSize(14)
          .fontColor(Color.Red)
          .margin({ top: 8 })
      }
    }
  }

  /**
   * 验证主密码
   */
  private async verifyMasterPassword(): Promise<boolean> {
    const result = await this.viewModel.verifyMasterPassword(this.passwordInput);
    if (result) {
      this.passwordInput = '';
      this.passwordError = '';
      return true;
    } else {
      this.passwordError = AppTextResolver.resource(this.viewModel.errorMessage ??
        new AppText(AppTextKey.VERIFICATION_FAILED));
      return false;
    }
  }

  private async loadQuickActionCipher(cipher: Cipher): Promise<Cipher | null> {
    if (this.isQuickActionLoading) {
      return null;
    }
    if (!this.viewModel.symmetricKey) {
      AppToast.show(this.getUIContext(), $r('app.string.common_loading'));
      return null;
    }
    this.isQuickActionLoading = true;
    try {
      const detailViewModel = new CipherDetailViewModel();
      detailViewModel.symmetricKey = this.viewModel.symmetricKey;
      const detail = JSON.parse(JSON.stringify(cipher)) as Cipher;
      return await detailViewModel.getCipherDetail(detail);
    } catch (error) {
      const err = error as Error;
      Logger.error(`Failed to load cipher for quick action: ${err.message}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_load_failed'));
      return null;
    } finally {
      this.isQuickActionLoading = false;
    }
  }

  private async copyCipherField(cipher: Cipher, field: CipherCopyField): Promise<void> {
    const detail = await this.loadQuickActionCipher(cipher);
    if (!detail) {
      return;
    }
    const value = await this.getCopyFieldValue(detail, field);
    if (value.length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.vault_copy_field_empty'));
      return;
    }
    await this.copyQuickActionText(value);
  }

  private async getCopyFieldValue(cipher: Cipher, field: CipherCopyField): Promise<string> {
    if (field === CipherCopyField.USERNAME) {
      if (cipher.type === CipherItemType.LOGIN) {
        return cipher.login?.username ?? '';
      }
      if (cipher.type === CipherItemType.IDENTITY) {
        return cipher.identity?.username ?? '';
      }
    }
    if (field === CipherCopyField.PASSWORD && cipher.type === CipherItemType.LOGIN) {
      return cipher.login?.password ?? '';
    }
    if (field === CipherCopyField.TOTP && cipher.type === CipherItemType.LOGIN && cipher.login?.totp) {
      const code = await TOTPUtil.generateTOTP(cipher.login.totp);
      return code === '------' ? '' : code;
    }
    if (field === CipherCopyField.CARD_NUMBER && cipher.type === CipherItemType.CARD) {
      return cipher.card?.number ?? '';
    }
    if (field === CipherCopyField.SECURITY_CODE && cipher.type === CipherItemType.CARD) {
      return cipher.card?.code ?? '';
    }
    if (field === CipherCopyField.EMAIL && cipher.type === CipherItemType.IDENTITY) {
      return cipher.identity?.email ?? '';
    }
    if (field === CipherCopyField.PHONE && cipher.type === CipherItemType.IDENTITY) {
      return cipher.identity?.phone ?? '';
    }
    if (field === CipherCopyField.ADDRESS && cipher.type === CipherItemType.IDENTITY && cipher.identity) {
      return this.buildIdentityAddress(cipher.identity);
    }
    return '';
  }

  private buildIdentityAddress(identity: CipherIdentity): string {
    const lines: string[] = [];
    this.appendAddressPart(lines, identity.address1);
    this.appendAddressPart(lines, identity.address2);
    this.appendAddressPart(lines, identity.address3);
    const localityParts: string[] = [];
    this.appendAddressPart(localityParts, identity.city);
    this.appendAddressPart(localityParts, identity.state);
    this.appendAddressPart(localityParts, identity.postalCode);
    if (localityParts.length > 0) {
      lines.push(localityParts.join(' '));
    }
    this.appendAddressPart(lines, identity.country);
    return lines.join('\n');
  }

  private appendAddressPart(parts: string[], value: string | null | undefined): void {
    const normalized = value?.trim() ?? '';
    if (normalized.length > 0) {
      parts.push(normalized);
    }
  }

  private async copyQuickActionText(text: string): Promise<void> {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(pasteData);
      AppToast.show(this.getUIContext(), $r('app.string.totp_copied'));
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to copy cipher quick action value: ${err.message}`);
      AppToast.show(this.getUIContext(), $r('app.string.totp_copy_failed'));
    }
  }

  private async openCipherUrl(cipher: Cipher): Promise<void> {
    const detail = await this.loadQuickActionCipher(cipher);
    if (!detail) {
      return;
    }
    const uris: string[] = [];
    for (const item of detail.login?.uris ?? []) {
      const uri = item.uri.trim();
      if (uri.length > 0) {
        uris.push(uri);
      }
      if (uris.length === 6) {
        break;
      }
    }
    if (uris.length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.vault_no_url'));
      return;
    }
    if (uris.length === 1) {
      await this.launchUrl(uris[0]);
      return;
    }
    try {
      const selectedIndex = await this.showQuickActionMenu(uris);
      if (selectedIndex >= 0 && selectedIndex < uris.length) {
        await this.launchUrl(uris[selectedIndex]);
      }
    } catch (_) {
      return;
    }
  }

  private async launchUrl(value: string): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const uri = /^[A-Za-z][A-Za-z0-9+.-]*:/.test(value) ? value : `http://${value}`;
      const want: Want = { uri: uri };
      await context.startAbility(want);
    } catch (error) {
      const err = error as Error;
      Logger.error(`Failed to open cipher URL: ${err.message}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
    }
  }

  private resolveResource(resource: Resource): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
  }

  private async showQuickActionMenu(labels: string[]): Promise<number> {
    const buttons: promptAction.Button[] = labels.slice(0, 6)
      .map((label: string) => new QuickActionMenuButton(label));
    let menuOptions: promptAction.ActionMenuOptions;
    switch (buttons.length) {
      case 1:
        menuOptions = { buttons: [buttons[0]] };
        break;
      case 2:
        menuOptions = { buttons: [buttons[0], buttons[1]] };
        break;
      case 3:
        menuOptions = { buttons: [buttons[0], buttons[1], buttons[2]] };
        break;
      case 4:
        menuOptions = { buttons: [buttons[0], buttons[1], buttons[2], buttons[3]] };
        break;
      case 5:
        menuOptions = { buttons: [buttons[0], buttons[1], buttons[2], buttons[3], buttons[4]] };
        break;
      case 6:
        menuOptions = { buttons: [buttons[0], buttons[1], buttons[2], buttons[3], buttons[4], buttons[5]] };
        break;
      default:
        return -1;
    }
    const result: promptAction.ActionMenuSuccessResponse =
      await this.getUIContext().getPromptAction().showActionMenu(menuOptions);
    return result.index;
  }
}

/** 承载密码库、TOTP、分享与设置页签的主页面。 */
@Component
export struct VaultPage {
  @StorageLink('localeRevision') localeRevision: number = 0;
  @StorageLink('isSplitView') @Watch('handleSplitViewChange') isSplitView: boolean = false;
  @StorageLink('activeSplitView') activeSplitView: boolean = false;
  @State selectedMainTab: MainTab = MainTab.VAULT;
  @State sharedCiphers: Cipher[] = [];
  @State sharedSymmetricKey: string = '';
  @State vaultDataRevision: number = 0;
  @State vaultActivationRevision: number = 0;
  @State vaultManualRefreshRevision: number = 0;
  private isPc: boolean = FormFactorUtil.isPc();
  private tabsController: TabsController = new TabsController();
  private exitTime: number = 0;
  @State pathInfos: NavPathStack = new NavPathStack();
  @State detailStack: NavPathStack = new NavPathStack();
  private closeDetailHandler: () => void = (): void => {
    this.applyPendingSplitViewChange();
    if (this.activeSplitView) {
      this.showDetailPlaceholder();
      return;
    }
    this.pathInfos.pop();
  };

  aboutToDisappear(): void {
    DetailRouter.unregisterCloseHandler(this.closeDetailHandler);
  }
  historyBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_history'),
      icon: $r('app.media.icon_history'),
      action: () => {
        this.openDetail(EntryRouter.ShareHistoryPage);
      }
    }
  };
  generatorHistoryBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_history'),
      icon: $r('app.media.icon_history'),
      action: () => {
        this.openDetail(EntryRouter.GeneratorHistoryPage);
      }
    }
  };

  private getTitle(): ResourceStr {
    if (this.selectedMainTab === MainTab.TOTP) {
      return $r('app.string.nav_totp');
    }
    if (this.selectedMainTab === MainTab.GENERATOR) {
      return $r('app.string.generator_title');
    }
    if (this.selectedMainTab === MainTab.SHARE) {
      return $r('app.string.nav_share');
    }
    if (this.selectedMainTab === MainTab.SETTINGS) {
      return $r('app.string.nav_settings');
    }
    return $r('app.string.nav_vault');
  }

  private selectTab(tab: MainTab): void {
    if (this.selectedMainTab === tab) {
      return;
    }
    if (this.activeSplitView) {
      DetailLeaveGuard.requestLeave(() => {
        this.applyPendingSplitViewChange();
        if (this.activeSplitView) {
          this.showDetailPlaceholder();
        }
        this.selectedMainTab = tab;
        this.tabsController.changeIndex(tab);
      });
      return;
    }
    this.selectedMainTab = tab;
    this.tabsController.changeIndex(tab);
  }

  private getTabByIndex(index: number): MainTab {
    if (index === MainTab.TOTP) {
      return MainTab.TOTP;
    }
    if (index === MainTab.GENERATOR) {
      return MainTab.GENERATOR;
    }
    if (index === MainTab.SHARE) {
      return MainTab.SHARE;
    }
    if (index === MainTab.SETTINGS) {
      return MainTab.SETTINGS;
    }
    return MainTab.VAULT;
  }

  private getTitleMenu(): HdsNavigationBadgeIconOptions[] {
    if (this.selectedMainTab === MainTab.SHARE) {
      return [this.historyBtn];
    }
    if (this.selectedMainTab === MainTab.GENERATOR) {
      return [this.generatorHistoryBtn];
    }
    return [];
  }

  private addCipher(): void {
    if (this.sharedSymmetricKey.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.common_loading') });
      return;
    }
    this.openDetail(EntryRouter.AddCipherPage, this.sharedSymmetricKey);
  }

  private refreshVault(): void {
    this.vaultManualRefreshRevision++;
  }

  private updateVaultData(ciphers: Cipher[], symmetricKey: string): void {
    this.sharedCiphers = ciphers;
    this.sharedSymmetricKey = symmetricKey;
    // 修订号让已挂载的 TOTP 页感知数组内容更新，而不依赖引用比较。
    this.vaultDataRevision++;
  }

  private navigateToCipherDetail(params: CipherDetailParams): void {
    this.openDetail(EntryRouter.CipherDetailPage, params);
  }

  private openDetail(name: string, param?: Object): void {
    if (!this.activeSplitView) {
      DetailRouter.openDetail(this.pathInfos, this.detailStack, false, name, param);
      return;
    }
    DetailLeaveGuard.requestLeave(() => {
      this.applyPendingSplitViewChange();
      DetailRouter.openDetail(this.pathInfos, this.detailStack, this.activeSplitView, name, param);
    });
  }

  private showDetailPlaceholder(): void {
    DetailRouter.showPlaceholder(this.detailStack);
  }

  private handleSplitViewChange(): void {
    if (this.isSplitView === this.activeSplitView) {
      return;
    }
    // 旋转是系统事件，无法“取消”，不应走“放弃改动”二次确认——否则取消后布局会卡在
    // 与朝向不符的模式（竖屏卡分栏 / 横屏卡单栏）。按设计 §8.6 直接迁移详情即可。
    // 注意：断点变化源自 Index.onAreaChange（处于渲染流水线中），同步改 @State 会被
    // 判为 "changed during render" 而丢弃，故延迟到当前帧结束后执行。
    // 未保存的编辑在跨栈迁移时会按原始数据重建而不保留（与“确认放弃”结果一致）。
    setTimeout(() => {
      this.applySplitViewChange();
    }, 0);
  }

  private applySplitViewChange(): void {
    // 幂等守卫：断点抖动（如折叠屏折叠/展开中途宽度短暂跌破阈值又回升）会让
    // handleSplitViewChange 入队的延迟调用在"模式已一致"时才触发。若不拦截，LG 分支
    // 会把当前显示的详情 replace 成占位页，导致用户正在看的详情凭空消失。
    if (this.isSplitView === this.activeSplitView) {
      return;
    }
    if (this.isSplitView) {
      const primaryPath = this.getTopDetailPath(this.pathInfos);
      if (primaryPath) {
        this.pathInfos.pop();
        const detailPathNames = this.detailStack.getAllPathName();
        if (!detailPathNames || detailPathNames.length === 0) {
          this.detailStack.pushPath(primaryPath);
        } else {
          this.detailStack.replacePath(primaryPath);
        }
      } else {
        this.showDetailPlaceholder();
      }
      this.activeSplitView = true;
      return;
    }

    const detailPath = this.getTopDetailPath(this.detailStack);
    this.showDetailPlaceholder();
    this.activeSplitView = false;
    if (detailPath) {
      this.pathInfos.pushPath(detailPath);
    }
  }

  private applyPendingSplitViewChange(): void {
    if (this.isSplitView !== this.activeSplitView) {
      this.applySplitViewChange();
    }
  }

  private getTopDetailPath(stack: NavPathStack): NavPathInfo | null {
    const paths = stack.getPathStack();
    if (!paths || paths.length === 0) {
      return null;
    }
    const path = paths[paths.length - 1];
    return this.isDetailPath(path.name) ? path : null;
  }

  private isDetailPath(name: string): boolean {
    return name === EntryRouter.CipherDetailPage || name === EntryRouter.AddCipherPage ||
      name === EntryRouter.ShareHistoryPage || name === EntryRouter.GeneratorHistoryPage;
  }

  private lockVault(): void {
    this.pathInfos.replacePath({ name: EntryRouter.UnlockPage });
  }

  private logout(): void {
    this.pathInfos.replacePath({ name: EntryRouter.LoginPage });
  }

  @Builder
  private vaultContent() {
    VaultContent({
      activationRevision: this.vaultActivationRevision,
      manualRefreshRevision: this.vaultManualRefreshRevision,
      pullToRefreshEnabled: !this.isPc,
      onVaultDataChanged: (ciphers: Cipher[], symmetricKey: string) => {
        this.updateVaultData(ciphers, symmetricKey);
      },
      onNavigateToDetail: (params: CipherDetailParams) => {
        this.navigateToCipherDetail(params);
      },
      onRelogin: () => {
        this.logout();
      }
    })
  }

  @Builder
  private vaultRefreshButton() {
    AdaptiveIconButton({
      icon: $r('app.media.icon_restore'),
      accessibilityLabel: $r('app.string.common_refresh'),
      iconWidth: 25,
      iconHeight: 25,
      contentPadding: 8,
      barBottomMargin: 0,
      onButtonClick: () => this.refreshVault()
    })
  }

  @Builder
  private vaultAddButton() {
    AdaptiveIconButton({
      icon: $r('app.media.icon_add'),
      accessibilityLabel: $r('app.string.cipher_add_title'),
      iconWidth: 25,
      iconHeight: 25,
      contentPadding: 8,
      barBottomMargin: 0,
      onButtonClick: () => this.addCipher()
    })
  }

  @Builder
  private totpContent() {
    TotpListPage({
      ciphers: this.sharedCiphers,
      symmetricKey: this.sharedSymmetricKey,
      isActive: this.selectedMainTab === MainTab.TOTP,
      dataRevision: this.vaultDataRevision,
      onNavigateToDetail: (params: CipherDetailParams) => {
        this.navigateToCipherDetail(params);
      }
    })
  }

  @Builder
  private splitListPane() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Text(this.getTitle()).fontSize(24).fontWeight(FontWeight.Medium).layoutWeight(1)
          if (this.selectedMainTab === MainTab.SHARE || this.selectedMainTab === MainTab.GENERATOR) {
            Image($r('app.media.icon_history'))
              .width(24)
              .height(24)
              .accessibilityText($r('app.string.common_history'))
              .onClick(() => {
                const name = this.selectedMainTab === MainTab.SHARE ?
                  EntryRouter.ShareHistoryPage : EntryRouter.GeneratorHistoryPage;
                this.openDetail(name);
              })
          }
        }
        .height(56)
        .padding({ left: 16, right: 16 })

        Column() {
          if (this.selectedMainTab === MainTab.VAULT) {
            this.vaultContent()
          } else if (this.selectedMainTab === MainTab.TOTP) {
            this.totpContent()
          } else if (this.selectedMainTab === MainTab.GENERATOR) {
            GeneratorPage({ bottomContentInset: 0 })
          } else if (this.selectedMainTab === MainTab.SHARE) {
            Sure2SharePage()
          } else {
            SettingsPage({
              isActive: true,
              onLockVault: () => this.lockVault(),
              onLogout: () => this.logout()
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      if (this.selectedMainTab === MainTab.VAULT && this.sharedSymmetricKey.length > 0) {
        Column() {
          if (this.isPc) {
            this.vaultRefreshButton()
          }
          this.vaultAddButton()
        }
        .margin({ right: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private splitRail() {
    MainSideRail({
      selectedMainTab: this.selectedMainTab,
      onSelect: (tab: MainTab) => this.selectTab(tab)
    })
  }

  @Builder
  private splitDetailPane() {
    Navigation(this.detailStack) {
    }
    .width('100%')
    .height('100%')
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }

  @Builder
  private compactContent() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Tabs({ barPosition: BarPosition.End, index: this.selectedMainTab, controller: this.tabsController }) {
          TabContent() {
            this.vaultContent()
          }
          TabContent() {
            this.totpContent()
          }
          TabContent() {
            GeneratorPage({ bottomContentInset: 0 })
          }
          TabContent() {
            Sure2SharePage()
          }
          TabContent() {
            SettingsPage({
              isActive: this.selectedMainTab === MainTab.SETTINGS,
              onLockVault: () => {
                this.lockVault();
              },
              onLogout: () => {
                this.logout();
              }
            })
          }
        }
        .barHeight(0)
        .scrollable(true)
        .layoutWeight(1)
        .onChange((index: number) => {
          this.selectedMainTab = this.getTabByIndex(index);
        })

        MainBottomNavigation({
          selectedMainTab: this.selectedMainTab,
          onSelect: (tab: MainTab) => {
            this.selectTab(tab);
          }
        })
      }
      .width('100%')
      .height('100%')

      if (this.selectedMainTab === MainTab.VAULT && this.sharedSymmetricKey.length > 0) {
        Column() {
          if (this.isPc) {
            this.vaultRefreshButton()
          }
          this.vaultAddButton()
        }
          .margin({ right: 8, bottom: 72 })
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    HdsNavDestination() {
      if (this.activeSplitView) {
        AdaptiveShell({
          railBuilder: (): void => this.splitRail(),
          listBuilder: (): void => this.splitListPane(),
          detailBuilder: (): void => this.splitDetailPane()
        })
      } else {
        this.compactContent()
      }
    }
    .titleBar({
      content: {
        title: { mainTitle: this.getTitle() },
        menu: { value: this.getTitleMenu() }
      },
      enableComponentSafeArea: true,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .hideTitleBar(this.activeSplitView)
    .hideBackButton(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
      DetailRouter.registerCloseHandler(this.closeDetailHandler);
    })
    .onActive(() => {
      // NavDestination 返回前台时通知密码库内容消费本地增删改。
      this.vaultActivationRevision++;
      this.applyPendingSplitViewChange();
    })
    .onAppear(() => {
      this.activeSplitView = this.isSplitView;
      DetailRouter.registerCloseHandler(this.closeDetailHandler);
      // onAppear 可能处于 ArkUI 初始渲染流水线中，延迟初始化详情栈，避免同步修改
      // @State detailStack；若期间已打开详情，则不再用占位页覆盖。
      setTimeout(() => {
        this.detailStack.disableAnimation(true);
        const pathNames = this.detailStack.getAllPathName();
        if (!pathNames || pathNames.length === 0) {
          this.showDetailPlaceholder();
        }
      }, 0);
    })
    .onBackPressed(() => {
      const currentTime = Date.now();
      if (currentTime - this.exitTime < 2000) {
        (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
      } else {
        this.exitTime = currentTime;
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.common_back_exit') });
      }
      return true;
    })
  }
}
