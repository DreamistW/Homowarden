import { EntryRouter } from '../../../../EntryRouter';
import { Cipher } from '../model/CipherModels';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { common } from '@kit.AbilityKit';
import { IBestDialog } from '@ibestservices/ibest-ui';
import { DataPreferences } from '@abner/datastore';
import { LOGIN_STATUS_KEY } from '../utils/Constants';
import { PromptAction } from '@kit.ArkUI';
import { CipherItem } from '../component/CipherItem';

@Builder
export function VaultPageBuilder() {
  VaultPage();
}

@Component
export struct VaultPage {
  @State viewModel: VaultViewModel = new VaultViewModel();
  @State searchText: string = '';
  @State needReLogin: boolean = false;
  private exitTime: number = 0;
  pathInfos: NavPathStack = new NavPathStack();
  AddItemBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_add.svg', 'action': () => {
      this.pathInfos.pushPath({ name: EntryRouter.AddCipherPage });
    }
  }
  SettingsBtn: NavigationMenuItem = {
    'value': '', 'icon': 'resources/base/media/icon_settings.svg', 'action': () => {
      this.pathInfos.pushPath({ name: EntryRouter.SettingsPage });
    }
  }

  aboutToAppear() {
    this.loadCiphers();
  }

  private async loadCiphers() {
    // 设置重新登录回调
    this.viewModel.onReLoginRequired = () => {
      this.needReLogin = true;
    };

    await this.viewModel.loadCiphers();
  }

  @Builder
  reLoginDialogContent() {
    Column() {
      Text('需要重新登录才能使用')
        .margin(12)
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 搜索栏
        Row() {
          TextInput({
            placeholder: '搜索密码项...',
            text: this.searchText
          })
            .layoutWeight(1)
            .onChange((value: string) => {
              this.searchText = value;
              this.viewModel.filterCiphers('all', value);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

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
          List() {
            ForEach(this.viewModel.filteredCiphers, (cipher: Cipher) => {
              ListItem() {
                CipherItem({
                  cipher: cipher,
                  onTap: ()=>{this.navigateToDetail(cipher);}
                })
              }
            })
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16 })
        }

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
      }
      .width('100%')
      .height('100%')
    }
    .title('密码库')
    .hideBackButton(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onBackPressed(() => {
      const currentTime = new Date().getTime();
      if (currentTime - this.exitTime < 2000) {
        (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
      } else {
        let promptAction: PromptAction = this.getUIContext().getPromptAction();
        this.exitTime = currentTime;
        promptAction.showToast({
          message: '再按一次退出',
          duration: 2000
        })
      }
      return true;
    })
    .menus([this.AddItemBtn, this.SettingsBtn])
  }

  private navigateToDetail(cipher: Cipher) {
    this.pathInfos.pushPath({ name: EntryRouter.CipherDetailPage, param: cipher.id });
  }
} 