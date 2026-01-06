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
  IBestPullRefresh
} from '@ibestservices/ibest-ui';
import { DataPreferences } from '@abner/datastore';
import {
  AUTO_LOCK,
  BACKGROUND_TIMESTAMP,
  FilterType,
  LOGIN_STATUS_KEY,
  NEED_RELOAD_CIPHERS
} from '../utils/Constants';
import { CipherItem } from '../component/CipherItem';

@Builder
export function VaultPageBuilder() {
  VaultPage();
}

@Component
export struct VaultPage {
  @State viewModel: VaultViewModel = new VaultViewModel();
  private listScroller: ListScroller = new ListScroller();
  @State searchText: string = '';
  @State needReLogin: boolean = false;
  @State selectedType: FilterType | string = 0;
  @State isLoading: boolean = false;
  @State showPasswordDialog: boolean = false;
  @State passwordInput: string = '';
  @State passwordError: string = '';
  @State pendingCipher: Cipher | null = null;
  private exitTime: number = 0;
  pathInfos: NavPathStack = new NavPathStack();
  AddItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_add.svg', 'action': () => {
      this.pathInfos.pushPath({ name: EntryRouter.AddCipherPage, param: this.viewModel.symmetricKey });
    }
  }
  SettingsBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_settings.svg', 'action': () => {
      this.pathInfos.pushPath({ name: EntryRouter.SettingsPage });
    }
  }
  Sure2ShareBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_share.svg', 'action': () => {
      this.pathInfos.pushPath({ name: EntryRouter.Sure2SharePage });
    }
  }
  groupId: string = 'filter_menu';

  async aboutToAppear() {
    await this.loadCiphers();
  }

  private async loadCiphers() {
    // 设置重新登录回调
    this.viewModel.onReLoginRequired = () => {
      this.needReLogin = true;
    };

    await this.viewModel.loadCiphers();
    this.viewModel.filterCiphers(this.selectedType, this.searchText);
    this.isLoading = false;
  }

  @Builder
  reLoginDialogContent() {
    Column() {
      Text(this.viewModel.errorMessage)
        .margin(12)
    }
  }

  @Builder
  passwordVerifyDialogContent() {
    Column({ space: 16 }) {
      Text('请输入主密码以查看此密码项')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      TextInput({ placeholder: '主密码', text: this.passwordInput })
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
  listContent() {
    Scroll(this.listScroller) {
      // 密码项列表
      if (this.viewModel.isLoading) {
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
      } else if (this.viewModel.filteredCiphers.length === 0) {
        Column() {
          Text('暂无密码项')
            .fontSize(16)
            .fontColor(Color.Gray)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
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
        .padding({ left: 16, right: 16 })
        .safeAreaPadding({ bottom: $r('app.float.safe_area_bottom') })
        .edgeEffect(EdgeEffect.None)
      }
    }
  }

  build() {
    NavDestination() {
      Column() {
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
            placeholder: "搜索密码项...",
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
          onRefresh: () => this.loadCiphers(),
          isEnableSlideUp: false
        })

        // 重新登录弹框
        IBestDialog({
          visible: this.needReLogin,
          title: '重新登录',
          showCancelButton: false,
          closeOnClickOverlay: false,
          defaultBuilder: (): void => this.reLoginDialogContent(),
          onConfirm: () => {
            DataPreferences.getInstance().putSync(LOGIN_STATUS_KEY, 0);
            this.pathInfos.replacePath({ name: EntryRouter.LoginPage });
            return true;
          }
        })

        // 主密码验证弹框
        IBestDialog({
          visible: this.showPasswordDialog,
          title: '主密码验证',
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
      }
      .width('100%')
      .height('100%')
    }
    .title('密码库')
    .hideBackButton(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onActive(async () => {
      const result = DataPreferences.getInstance().getSync<number>(NEED_RELOAD_CIPHERS);
      if (result == 1) {
        await this.loadCiphers();
        DataPreferences.getInstance().putSync(NEED_RELOAD_CIPHERS, 0);
      }
    })
    .onBackPressed(() => {
      const currentTime = new Date().getTime();
      if (currentTime - this.exitTime < 2000) {
        (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
      } else {
        this.exitTime = currentTime;
        this.getUIContext().getPromptAction().showToast({
          message: "再按一次退出"
        });
      }
      return true;
    })
    .menus([this.Sure2ShareBtn, this.AddItemBtn, this.SettingsBtn])
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

  private navigateToDetail(cipher: Cipher) {
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

  private doNavigateToDetail(cipher: Cipher) {
    this.pathInfos.pushPath({
      name: EntryRouter.CipherDetailPage,
      param: { cipher: cipher, symmetricKey: this.viewModel.symmetricKey } as CipherDetailParams
    });
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
      this.passwordError = this.viewModel.errorMessage;
      return false;
    }
  }
} 