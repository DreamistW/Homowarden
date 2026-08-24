import { Cipher, CipherDetailParams } from '../model/CipherModels';
import { TotpListItem } from '../component/TotpListItem';
import { TotpListViewModel } from '../viewmodel/TotpListViewModel';
import { AppText, AppTextKey } from '../localization/AppText';
import { AppTextResolver } from '../localization/AppTextResolver';
import { FormDialog } from '../component/FormDialog';

/** 从密码库共享数据中筛选并展示 TOTP 条目的页签内容 */
@Component
export struct TotpListPage {
  @Prop bottomContentInset: number = 0;
  @Prop ciphers: Cipher[] = [];
  @Prop symmetricKey: string = '';
  @Prop @Watch('handleActiveChanged') isActive: boolean = false;
  @Prop @Watch('handleDataRevisionChanged') dataRevision: number = 0;
  onNavigateToDetail: (params: CipherDetailParams) => void = () => {};
  @State viewModel: TotpListViewModel = new TotpListViewModel();
  @State currentTime: number = Date.now();
  @State isLoading: boolean = true;
  @State passwordInput: string = '';
  @State passwordError: ResourceStr = '';
  @State pendingCipher: Cipher | null = null;
  private timerId: number = -1;
  private loadedRevision: number = -1;
  private passwordDialogController: CustomDialogController = new CustomDialogController({
    builder: FormDialog({
      title: $r('app.string.totp_master_title'),
      contentBuilder: (): void => this.masterPasswordContent(),
      cancel: () => {},
      confirm: async (): Promise<void> => {
        await this.confirmMasterPassword();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  aboutToAppear(): void {
    if (this.isActive) {
      void this.activate();
    }
  }

  aboutToDisappear(): void {
    // 页签不可见后停止秒级刷新，避免后台持续触发 UI 更新
    this.stopTimer();
  }

  private handleActiveChanged(): void {
    if (this.isActive) {
      void this.activate();
    } else {
      this.stopTimer();
    }
  }

  private handleDataRevisionChanged(): void {
    if (this.isActive) {
      void this.activate();
    }
  }

  private async activate(): Promise<void> {
    // 仅在密码库数据修订变化时重新解密，普通页签切换只恢复计时器
    if (this.loadedRevision !== this.dataRevision) {
      await this.reloadCiphers();
    }
    this.startTimer();
  }

  private async reloadCiphers(): Promise<void> {
    this.isLoading = true;
    this.viewModel.allCiphers = this.ciphers;
    this.viewModel.symmetricKey = this.symmetricKey;
    await this.viewModel.loadLogins();
    // 加载结束后记录当前修订号，避免普通页签切换重复解密同一批数据
    this.loadedRevision = this.dataRevision;
    this.isLoading = false;
  }

  private startTimer(): void {
    if (this.timerId !== -1 || !this.isActive) {
      return;
    }
    this.currentTime = Date.now();
    this.timerId = setInterval(() => {
      this.currentTime = Date.now();
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private navigateToDetail(cipher: Cipher): void {
    // 受 reprompt 保护的条目必须先验证主密码，不能直接携带密钥进入详情页
    if (cipher.reprompt === 1) {
      this.pendingCipher = cipher;
      this.passwordInput = '';
      this.passwordError = '';
      this.passwordDialogController.open();
    } else {
      this.doNavigateToDetail(cipher);
    }
  }

  private doNavigateToDetail(cipher: Cipher): void {
    const params: CipherDetailParams = { cipher: cipher, symmetricKey: this.symmetricKey };
    this.onNavigateToDetail(params);
  }

  // 密码验证弹框点击确认时调用：校验通过则跳转详情并关闭弹框，否则回填错误文案并保持打开
  private async confirmMasterPassword(): Promise<void> {
    const result = await this.verifyMasterPassword();
    if (result) {
      if (this.pendingCipher) {
        this.doNavigateToDetail(this.pendingCipher);
        this.pendingCipher = null;
      }
      this.passwordDialogController.close();
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

  build() {
    Column() {
      if (this.isLoading) {
        Column() {
          Text($r('app.string.common_loading'))
            .fontSize(16)
            .fontColor('#666666')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.viewModel.filteredCiphers.length === 0) {
        Column() {
          Image($r('app.media.icon_key'))
            .width(80)
            .height(80)
            .fillColor('#CCCCCC')
            .margin({ bottom: 16 })
          Text($r('app.string.totp_empty'))
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
        .contentEndOffset(this.bottomContentInset)
      }
    }
    .width('100%')
    .height('100%')
  }

  private async verifyMasterPassword(): Promise<boolean> {
    const result = await this.viewModel.verifyMasterPassword(this.passwordInput);
    if (result) {
      this.passwordInput = '';
      this.passwordError = '';
      return true;
    }
    this.passwordError = AppTextResolver.resource(this.viewModel.errorMessage ??
      new AppText(AppTextKey.VERIFICATION_FAILED));
    return false;
  }
}
