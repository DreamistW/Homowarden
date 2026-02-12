import { Cipher, CipherDetailParams, TotpListParams } from '../model/CipherModels';
import { EntryRouter } from '../../../../EntryRouter';
import { TotpListItem } from '../component/TotpListItem';
import { TotpListViewModel } from '../viewmodel/TotpListViewModel';
import { IBestDialog } from '@ibestservices/ibest-ui';

@Builder
export function TotpListPageBuilder() {
  TotpListPage();
}

@Component
export struct TotpListPage {
  @State viewModel: TotpListViewModel = new TotpListViewModel();
  @State currentTime: number = Date.now();
  @State isLoading: boolean = true;
  @State showPasswordDialog: boolean = false;
  @State passwordInput: string = '';
  @State passwordError: string = '';
  @State pendingCipher: Cipher | null = null;
  private timerId: number = -1;
  pathInfos: NavPathStack = new NavPathStack();

  aboutToDisappear() {
    this.stopTimer();
  }

  /**
   * 启动定时器
   */
  private startTimer() {
    this.timerId = setInterval(() => {
      this.currentTime = Date.now();
    }, 1000);
  }

  /**
   * 停止定时器
   */
  private stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 跳转到密码项详情
   */
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

  build() {
    NavDestination() {
      Column() {
        // 内容区
        if (this.isLoading) {
          Column() {
            Text('加载中...')
              .fontSize(16)
              .fontColor('#666666')
              .margin({ top: 40 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.viewModel.filteredCiphers.length === 0) {
          Column() {
            Image($r('app.media.icon_time'))
              .width(80)
              .height(80)
              .fillColor('#CCCCCC')
              .margin({ bottom: 16 })

            Text('暂无验证码')
              .fontSize(16)
              .fontColor('#999999')
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.viewModel.filteredCiphers, (cipher: Cipher) => {
              ListItem() {
                TotpListItem({
                  cipher: cipher,
                  currentTime: this.currentTime,
                  onTap: () => {
                    this.navigateToDetail(cipher);
                  }
                })
              }
            })
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
        }

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
    .title('验证码')
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
      const param = ctx.pathInfo.param as TotpListParams;
      if (param.ciphers) {
        this.viewModel.allCiphers = param.ciphers;
        this.viewModel.symmetricKey = param.symmetricKey;
        this.viewModel.loadLogins();
      }
      this.isLoading = false;
      // 启动全局定时器
      this.startTimer();
    })
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
}
