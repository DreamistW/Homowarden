import { replacePage, RouterPath, setRouterLifeCycle, startPage, startPageByName } from '@abner/router';
import { EntryRouter } from '../../../../EntryRouter';
import { Cipher } from '../model/CipherModels';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { common } from '@kit.AbilityKit';
import { IBestDialog } from '@ibestservices/ibest-ui';
import { DataPreferences } from '@abner/datastore';
import { LOGIN_STATUS_KEY } from '../utils/Constants';
import { PromptAction } from '@kit.ArkUI';

@RouterPath(EntryRouter.VaultPage)
@Component
export struct VaultPage {
  @State viewModel: VaultViewModel = new VaultViewModel();
  @State searchText: string = '';
  @State needReLogin: boolean = false;
  private exitTime: number = 0;

  aboutToAppear() {
    this.loadCiphers();
    setRouterLifeCycle({
      onBackPressed: () => {
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
      }
    })
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
    Column() {
      // 顶部导航栏
      Row() {
        Text('密码库')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)

        Blank()

        Button() {
          Text('设置')
            .fontSize(16)
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          startPage(EntryRouter.SettingsPage);
        })
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })

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
              Row() {
                Column() {
                  Text(cipher.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)

                  Text(cipher.login?.username || cipher.card?.number || '')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button() {
                  Text(cipher.favorite ? '★' : '☆')
                    .fontSize(20)
                }
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  cipher.favorite = !cipher.favorite;
                })
              }
              .width('100%')
              .padding(16)
              .borderRadius(8)
              .margin({ bottom: 8 })
              .onClick(() => {
                this.navigateToDetail(cipher);
              })
            }
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16 })
      }

      // 悬浮添加按钮
      Button() {
        Text('+')
          .fontSize(24)
          .fontColor(Color.White)
      }
      .width(56)
      .height(56)
      .backgroundColor('#007AFF')
      .borderRadius(28)
      .position({ x: '75%', y: '85%' })
      .onClick(() => {
        this.navigateToAdd();
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
          replacePage(EntryRouter.LoginPage);
          return true;
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  private navigateToDetail(cipher: Cipher) {
    startPage(EntryRouter.CipherDetailPage, { param: cipher.id })
  }

  private navigateToAdd() {
    startPage(EntryRouter.AddCipherPage)
  }
} 