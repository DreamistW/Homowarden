import { EntryRouter } from '../../../../EntryRouter';
import { Cipher, CipherDetailParams } from '../model/CipherModels';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { common } from '@kit.AbilityKit';
import { AppToast } from '../utils/AppToast';
import { AppDropdown } from '../component/AppDropdown';
import { AppDialog, AppDialogAction } from '../component/AppDialog';
import { DataPreferences } from '@abner/datastore';
import {
  FilterType, LOGIN_STATUS_KEY, NEED_RELOAD_CIPHERS
} from '../utils/Constants';
import { CipherItem } from '../component/CipherItem';
import {
  HdsNavDestination, HdsNavigationBadgeIconOptions
} from '@hms.hds.hdsBaseComponent';
import { hdsMaterial } from '@kit.UIDesignKit';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { VaultChangeNotifier, VaultLocalChange, VaultLocalChangeType } from '../utils/VaultChangeNotifier';
import { MainBottomNavigation, MainTab } from '../component/MainBottomNavigation';
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

@Builder
export function VaultPageBuilder() {
  VaultPage();
}

@Component
struct VaultContent {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  @StorageLink('vaultCommittedChangeRevision') @Watch('handleCommittedChange') committedChangeRevision: number = 0;
  @Prop @Watch('handleActivationRevision') activationRevision: number = 0;
  onVaultDataChanged: (ciphers: Cipher[], symmetricKey: string) => void = () => {};
  onNavigateToDetail: (params: CipherDetailParams) => void = () => {};
  onRelogin: () => void = () => {};
  @State viewModel: VaultViewModel = new VaultViewModel();
  private listScroller: ListScroller = new ListScroller();
  @State searchText: string = '';
  @State needReLogin: boolean = false;
  @State selectedType: FilterType = FilterType.ALL;
  @State filterOptions: AppDropdownOption[] = AppOptionFactory.vaultFilters(0, 0, 0, 0, 0, 0, 0);
  @State displayCiphers: Cipher[] = [];
  @State isInitialLoading: boolean = true;
  @State isLoading: boolean = false;
  @State showPasswordDialog: boolean = false;
  @State passwordInput: string = '';
  @State passwordError: ResourceStr = '';
  @State pendingCipher: Cipher | null = null;
  groupId: string = 'filter_menu';

  async aboutToAppear(): Promise<void> {
    await this.loadCiphersWithBackgroundSync();
    this.consumeCommittedChange();
  }

  private handleActivationRevision(): void {
    this.consumeCommittedChange();
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

  @Builder
  reLoginDialogContent() {
    Column() {
      Text($r('app.string.vault_relogin_message'))
        .margin(12)
    }
  }

  @Builder
  passwordVerifyDialogContent() {
    Column({ space: 16 }) {
      Text($r('app.string.totp_master_prompt'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      TextInput({ placeholder: $r('app.string.unlock_enter_master_password'), text: this.passwordInput })
        .accessibilityText($r('app.string.unlock_enter_master_password'))
        .type(InputType.Password)
        .onChange((value: string) => {
          this.passwordInput = value;
          this.passwordError = '';
        })
        .margin({ left: 12, right: 12 })
      if (this.passwordError) {
        Text(this.passwordError)
          .fontSize(14)
          .fontColor(Color.Red)
          .margin({ left: 12, right: 12 })
      }
    }
    .padding({ top: 12, bottom: 12 })
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
          }

          // 重新登录弹框
          AppDialog({
            visible: $needReLogin,
            title: $r('app.string.vault_relogin_title'),
            showCancelButton: false,
            closeOnClickOverlay: false,
            defaultBuilder: (): void => this.reLoginDialogContent(),
            beforeClose: async (action: AppDialogAction) => {
              if (action === AppDialogAction.CANCEL) {
                return false;
              }
              DataPreferences.getInstance().putSync(LOGIN_STATUS_KEY, 0);
              void WindowPrivacyUtil.applyForCurrentState();
              this.onRelogin();
              return true;
            }
          })

          // 主密码验证弹框
          AppDialog({
            visible: $showPasswordDialog,
            title: $r('app.string.totp_master_title'),
            showCancelButton: true,
            closeOnClickOverlay: false,
            defaultBuilder: (): void => this.passwordVerifyDialogContent(),
            beforeClose: async (action) => {
              if (action === AppDialogAction.CANCEL) {
                return true;
              }
              const result = await this.verifyMasterPassword();
              if (result) {
                // 验证成功，导航到详情页
                if (this.pendingCipher) {
                  this.doNavigateToDetail(this.pendingCipher);
                  this.pendingCipher = null;
                }
                return true;
              } else {
                return false;
              }
            }
          })

        }
        .width('100%')
        .height('100%')

      }
      .width('100%')
      .height('100%')
    }

  private navigateToDetail(cipher: Cipher): void {
    // 检查是否需要验证主密码
    if (cipher.reprompt === 1) {
      this.pendingCipher = cipher;
      this.passwordInput = '';
      this.passwordError = '';
      this.showPasswordDialog = true;
    } else {
      this.doNavigateToDetail(cipher);
    }
  }

  private doNavigateToDetail(cipher: Cipher): void {
    const params: CipherDetailParams = { cipher: cipher, symmetricKey: this.viewModel.symmetricKey };
    this.onNavigateToDetail(params);
  }

  /**
   * 验证主密码
   */
  private async verifyMasterPassword(): Promise<boolean> {
    const result = await this.viewModel.verifyMasterPassword(this.passwordInput);
    if (result) {
      this.passwordInput = '';
      this.passwordError = '';
      this.showPasswordDialog = false;
      return true;
    } else {
      this.passwordError = AppTextResolver.resource(this.viewModel.errorMessage ??
        new AppText(AppTextKey.VERIFICATION_FAILED));
      return false;
    }
  }
}

/** 承载密码库、TOTP、分享与设置页签的主页面。 */
@Component
export struct VaultPage {
  @StorageLink('localeRevision') localeRevision: number = 0;
  @StorageLink('isSplitView') @Watch('handleSplitViewChange') isSplitView: boolean = false;
  @State activeSplitView: boolean = false;
  @State selectedMainTab: MainTab = MainTab.VAULT;
  @State sharedCiphers: Cipher[] = [];
  @State sharedSymmetricKey: string = '';
  @State vaultDataRevision: number = 0;
  @State vaultActivationRevision: number = 0;
  private tabsController: TabsController = new TabsController();
  private exitTime: number = 0;
  @State pathInfos: NavPathStack = new NavPathStack();
  @State detailStack: NavPathStack = new NavPathStack();
  historyBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_history'),
      icon: $r('app.media.icon_history'),
      action: () => {
        DetailRouter.openHistory(this.pathInfos, this.detailStack, this.activeSplitView,
          EntryRouter.ShareHistoryPage);
      }
    }
  };
  generatorHistoryBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_history'),
      icon: $r('app.media.icon_history'),
      action: () => {
        DetailRouter.openHistory(this.pathInfos, this.detailStack, this.activeSplitView,
          EntryRouter.GeneratorHistoryPage);
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
        this.showDetailPlaceholder();
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
      DetailRouter.openDetail(this.pathInfos, this.detailStack, true, name, param);
    });
  }

  private showDetailPlaceholder(): void {
    this.detailStack.replacePath({ name: EntryRouter.DetailPlaceholder });
  }

  private handleSplitViewChange(): void {
    if (this.isSplitView === this.activeSplitView) {
      return;
    }
    DetailLeaveGuard.requestLeave(() => this.applySplitViewChange());
  }

  private applySplitViewChange(): void {
    if (this.isSplitView) {
      const primaryPath = this.getTopDetailPath(this.pathInfos);
      if (primaryPath) {
        this.pathInfos.pop();
        this.detailStack.replacePath(primaryPath);
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

  private getTopDetailPath(stack: NavPathStack): NavPathInfo | null {
    const paths = stack.getPathStack();
    if (paths.length === 0) {
      return null;
    }
    const path = paths[paths.length - 1];
    return path.name === EntryRouter.DetailPlaceholder ? null : path;
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
      .height('100%')

      if (this.selectedMainTab === MainTab.VAULT && this.sharedSymmetricKey.length > 0) {
        AdaptiveIconButton({
          icon: $r('app.media.icon_add'),
          accessibilityLabel: $r('app.string.cipher_add_title'),
          iconWidth: 25,
          iconHeight: 25,
          contentPadding: 8,
          barBottomMargin: 0,
          onButtonClick: () => this.addCipher()
        }).margin({ right: 8, bottom: 8 })
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
        Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
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
        AdaptiveIconButton({
          icon: $r('app.media.icon_add'),
          accessibilityLabel: $r('app.string.cipher_add_title'),
          iconWidth: 25,
          iconHeight: 25,
          contentPadding: 8,
          barBottomMargin: 0,
          onButtonClick: () => {
            this.addCipher();
          }
        })
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
      DetailRouter.registerDetailStack(this.detailStack);
    })
    .onActive(() => {
      // NavDestination 返回前台时通知密码库内容消费本地增删改。
      this.vaultActivationRevision++;
    })
    .onAppear(() => {
      this.activeSplitView = this.isSplitView;
      DetailRouter.registerDetailStack(this.detailStack);
      this.showDetailPlaceholder();
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
