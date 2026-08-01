import { EntryRouter } from '../../../../EntryRouter';
import { Cipher, CipherDetailParams } from '../model/CipherModels';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { common } from '@kit.AbilityKit';
import {
  IBestDialog,
  IBestDropdownItem,
  IBestDropdownMenu,
  IBestField,
  IBestFieldValueType,
  IBestPullRefresh,
  IBestToast
} from '@ibestservices/ibest-ui';
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
import { AppText, AppTextKey } from '../localization/AppText';
import { AppTextResolver } from '../localization/AppTextResolver';
import { AdaptiveIconButton } from '../component/AdaptiveButton';

@Builder
export function VaultPageBuilder() {
  VaultPage();
}

@Component
struct VaultContent {
  @StorageLink('localeRevision') @Watch('handleLocaleRevision') localeRevision: number = 0;
  @Prop @Watch('handleActivationRevision') activationRevision: number = 0;
  onVaultDataChanged: (ciphers: Cipher[], symmetricKey: string) => void = () => {};
  onNavigateToDetail: (params: CipherDetailParams) => void = () => {};
  onRelogin: () => void = () => {};
  @State viewModel: VaultViewModel = new VaultViewModel();
  private listScroller: ListScroller = new ListScroller();
  @State searchText: string = '';
  @State needReLogin: boolean = false;
  @State selectedType: FilterType | string = 0;
  @State isInitialLoading: boolean = true;
  @State isLoading: boolean = false;
  @State showPasswordDialog: boolean = false;
  @State passwordInput: string = '';
  @State passwordError: ResourceStr = '';
  @State pendingCipher: Cipher | null = null;
  groupId: string = 'filter_menu';

  async aboutToAppear(): Promise<void> {
    await this.loadCiphersWithBackgroundSync();
  }

  private handleActivationRevision(): void {
    const result = DataPreferences.getInstance().getSync<number>(NEED_RELOAD_CIPHERS);
    if (result === 1) {
      DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 0);
      void this.handleLocalVaultChange(VaultChangeNotifier.consumeChange());
    }
  }

  private handleLocaleRevision(): void {
    this.viewModel.refreshLocale();
    this.viewModel.filterCiphers(this.selectedType, this.searchText);
    this.publishVaultData();
  }

  private publishVaultData(): void {
    this.onVaultDataChanged(this.viewModel.allCiphers, this.viewModel.symmetricKey);
  }

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
        IBestToast.show($r('app.string.error_load_failed'));
      }

      this.viewModel.filterCiphers(this.selectedType, this.searchText);
      this.publishVaultData();

      // 第二步：如果本地没数据，则直接强制同步，避免先显示空态再跳变为列表
      if (this.viewModel.allCiphers.length === 0) {
        const syncResult = await this.viewModel.loadCiphers(true);
        if (!syncResult && !this.needReLogin) {
          IBestToast.show($r('app.string.error_load_failed'));
        }
        this.viewModel.filterCiphers(this.selectedType, this.searchText);
        this.publishVaultData();
        return;
      }

      // 第三步：本地已有数据，则后台静默同步
      void this.doBackgroundSync();
    } finally {
      this.isInitialLoading = false;
    }
  }

  private async doBackgroundSync() {
    const changeRevision = VaultChangeNotifier.getChangeRevision();
    const result = await this.viewModel.syncCiphersInBackground(() => {
      return changeRevision === VaultChangeNotifier.getChangeRevision();
    });

    if (result) {
      // 后台同步完成后，重新应用当前筛选条件
      this.viewModel.filterCiphers(this.selectedType, this.searchText);
      this.publishVaultData();
    } else {
      // 后台同步失败时，不影响已显示的本地数据
      if (!this.needReLogin && this.viewModel.errorMessage) {
        IBestToast.show($r('app.string.vault_sync_failed_local'));
      }
    }
  }

  private async reloadCiphersAfterLocalChange() {
    const localResult = await this.viewModel.loadCiphers(false);
    if (localResult) {
      this.viewModel.filterCiphers(this.selectedType, this.searchText);
      this.publishVaultData();
    } else {
      IBestToast.show($r('app.string.error_load_failed'));
    }
    void this.doBackgroundSync();
  }

  private async handleLocalVaultChange(change: VaultLocalChange | null): Promise<void> {
    if (change?.type === VaultLocalChangeType.UPSERT && change.cipher) {
      this.viewModel.applyLocalCipherChange(change.cipher, this.selectedType, this.searchText);
      void this.reloadCiphersAfterLocalChange();
      return;
    }

    if (change?.type === VaultLocalChangeType.DELETE && change.cipherId) {
      this.viewModel.applyLocalCipherDeletion(change.cipherId, this.selectedType, this.searchText);
      void this.reloadCiphersAfterLocalChange();
      return;
    }

    await this.reloadCiphersAfterLocalChange();
  }

  private async loadCiphers(forceSync: boolean = true) {
    // 设置重新登录回调
    this.viewModel.onReLoginRequired = () => {
      this.needReLogin = true;
    };

    this.isLoading = true;
    const result = await this.viewModel.loadCiphers(forceSync);
    if (!result && !this.needReLogin) {
      IBestToast.show($r('app.string.error_validation'));
    }
    this.viewModel.filterCiphers(this.selectedType, this.searchText);
    this.publishVaultData();
    this.isLoading = false;
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
  listContent() {
    Scroll(this.listScroller) {
      // 密码项列表
      if (this.viewModel.isLoading) {
        this.loadingContent()
      } else if (this.viewModel.filteredCiphers.length === 0) {
        this.emptyContent()
      } else {
        List({ scroller: this.listScroller }) {
          ForEach(this.viewModel.filteredCiphers, (cipher: Cipher) => {
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
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16})
        .safeAreaPadding({ bottom: $r('app.float.safe_area_bottom') })
        .edgeEffect(EdgeEffect.None)
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          if (this.isInitialLoading) {
            this.loadingContent()
          } else {
            // 搜索栏
            Row() {
              Column() {
                IBestDropdownMenu({ groupId: this.groupId }) {
                  IBestDropdownItem({
                    groupId: this.groupId,
                    options: this.viewModel.filterOptions,
                    value: this.selectedType,
                    onChange: value => {
                      this.viewModel.filterCiphers(value, this.searchText);
                      this.selectedType = value;
                    }
                  })
                }
              }.width('30%')

              IBestField({
                value: this.searchText,
                placeholder: $r('app.string.vault_search_placeholder'),
                showLabel: false,
                hasBorder: false,
                clearable: true,
                onChange: (value: IBestFieldValueType) => {
                  this.searchText = value as string;
                  this.viewModel.filterCiphers('all', this.searchText);
                }
              }).width('70%')
                .borderRadius(0)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })

            IBestPullRefresh({
              loading: $isLoading,
              scroller: this.listScroller,
              defaultContent: () => this.listContent(),
              onRefresh: () => this.loadCiphers(true),
              isEnableSlideUp: false
            })
          }

          // 重新登录弹框
          IBestDialog({
            visible: this.needReLogin,
            title: $r('app.string.vault_relogin_title'),
            showCancelButton: false,
            closeOnClickOverlay: false,
            defaultBuilder: (): void => this.reLoginDialogContent(),
            onConfirm: () => {
              DataPreferences.getInstance().putSync(LOGIN_STATUS_KEY, 0);
              void WindowPrivacyUtil.applyForCurrentState();
              this.onRelogin();
              return true;
            }
          })

          // 主密码验证弹框
          IBestDialog({
            visible: this.showPasswordDialog,
            title: $r('app.string.totp_master_title'),
            showCancelButton: true,
            closeOnClickOverlay: false,
            defaultBuilder: (): void => this.passwordVerifyDialogContent(),
            beforeClose: async (action) => {
              if (action === 'cancel') {
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

          // IBestFloatBubble({
          //   show: this.showAddBtn,
          //   icon: $r("app.media.icon_add"),
          //   onBubbleClick: () => {
          //     this.pathInfos.pushPath({ name: EntryRouter.AddCipherPage, param: this.viewModel.symmetricKey });
          //   }
          // })
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

@Component
export struct VaultPage {
  @StorageLink('localeRevision') localeRevision: number = 0;
  @State selectedMainTab: MainTab = MainTab.VAULT;
  @State sharedCiphers: Cipher[] = [];
  @State sharedSymmetricKey: string = '';
  @State vaultDataRevision: number = 0;
  @State vaultActivationRevision: number = 0;
  private tabsController: TabsController = new TabsController();
  private exitTime: number = 0;
  @State pathInfos: NavPathStack = new NavPathStack();
  historyBtn: HdsNavigationBadgeIconOptions = {
    content: {
      label: $r('app.string.common_history'),
      icon: $r('app.media.icon_history'),
      action: () => {
        this.pathInfos.pushPath({ name: EntryRouter.ShareHistoryPage });
      }
    }
  };

  private getTitle(): ResourceStr {
    if (this.selectedMainTab === MainTab.TOTP) {
      return $r('app.string.nav_totp');
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
    this.selectedMainTab = tab;
    this.tabsController.changeIndex(tab);
  }

  private getTabByIndex(index: number): MainTab {
    if (index === MainTab.TOTP) {
      return MainTab.TOTP;
    }
    if (index === MainTab.SHARE) {
      return MainTab.SHARE;
    }
    if (index === MainTab.SETTINGS) {
      return MainTab.SETTINGS;
    }
    return MainTab.VAULT;
  }

  private addCipher(): void {
    if (this.sharedSymmetricKey.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.common_loading') });
      return;
    }
    this.pathInfos.pushPath({ name: EntryRouter.AddCipherPage, param: this.sharedSymmetricKey });
  }

  private updateVaultData(ciphers: Cipher[], symmetricKey: string): void {
    this.sharedCiphers = ciphers;
    this.sharedSymmetricKey = symmetricKey;
    this.vaultDataRevision++;
  }

  private navigateToCipherDetail(params: CipherDetailParams): void {
    this.pathInfos.pushPath({ name: EntryRouter.CipherDetailPage, param: params });
  }

  private lockVault(): void {
    this.pathInfos.replacePath({ name: EntryRouter.UnlockPage });
  }

  private logout(): void {
    this.pathInfos.replacePath({ name: EntryRouter.LoginPage });
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
          TabContent() {
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
          TabContent() {
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
    .titleBar({
      content: {
        title: { mainTitle: this.getTitle() },
        menu: { value: this.selectedMainTab === MainTab.SHARE ? [this.historyBtn] : [] }
      },
      enableComponentSafeArea: true,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .hideBackButton(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onActive(() => {
      this.vaultActivationRevision++;
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
