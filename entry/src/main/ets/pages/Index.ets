import { DataPreferences } from '@abner/datastore';
import { finishPage, replacePage, routerInitNavPathStack, routerReturnBuilder, startPage } from '@abner/router';
import { EntryRouter } from '../../../../EntryRouter';
import { LOGIN_STATUS_KEY, PRIVACY_AGREED_KEY } from '../utils/Constants';
import { createTables } from '../utils/DatabaseUtil';
import { common } from '@kit.AbilityKit';

@CustomDialog
struct PrivacyDialogContent {
  controller?: CustomDialogController
  cancel: () => void = () => {
  }
  confirm: () => void = () => {
  }

  build() {
    Column() {
      Text("隐私协议")
        .fontSize(20)
        .margin({ top: 20, bottom: 10 })

      Text("请仔细阅读并同意用户协议与隐私政策")
        .fontSize(16)
        .margin({ bottom: 20 })

      Row() {
        Button('不同意')
          .onClick(() => {
            this.controller?.close();
            this.cancel();
          })
        Button('同意')
          .onClick(() => {
            this.controller?.close();
            this.confirm();
          })
      }.justifyContent(FlexAlign.SpaceEvenly)
    }.padding(20)
  }
}

@Entry
@Component
struct Index {
  private navPathStack: NavPathStack = new NavPathStack();
  @State private showPrivacyDialog: boolean = true;
  private isLogin: boolean = false;

  aboutToAppear(): void {
    routerInitNavPathStack(this.navPathStack);
    this.getLoginStatus();
  }

  onPageShow(): void {
    this.getPrivacyStatus();
    if (this.showPrivacyDialog) {
      this.privacyDialogController.open();
    } else {
      this.getLoginStatus();
      if (this.isLogin) {
        replacePage(EntryRouter.VaultPage);
      } else {
        replacePage(EntryRouter.LoginPage);
      }
    }
  }

  onPageHide(): void {
    this.privacyDialogController.close();
  }

  aboutToDisappear(): void {
    this.privacyDialogController.close();
  }

  privacyDialogController: CustomDialogController = new CustomDialogController({
    builder: PrivacyDialogContent({
      cancel: () => {
        this.onPrivacyRejected();
      },
      confirm: () => {
        this.onPrivacyAgreed();
      }
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center
  })

  getPrivacyStatus() {
    if (DataPreferences.getInstance().hasSync(PRIVACY_AGREED_KEY)) {
      const result = DataPreferences.getInstance().getSync<number>(PRIVACY_AGREED_KEY);
      this.showPrivacyDialog = (result != 1);
    }
  }

  getLoginStatus() {
    if (DataPreferences.getInstance().hasSync(LOGIN_STATUS_KEY)) {
      const result = DataPreferences.getInstance().getSync<number>(LOGIN_STATUS_KEY);
      this.isLogin = (result == 1);
    }
  }

  @Builder
  routerMap(builderName: string, param: Object) {
    routerReturnBuilder(builderName).builder(param)
  }

  onPrivacyRejected() {
    (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
  }

  onPrivacyAgreed() {
    DataPreferences.getInstance().putSync(PRIVACY_AGREED_KEY, 1);
    createTables();
    replacePage(EntryRouter.LoginPage);
  }

  build() {
    Navigation(this.navPathStack) {

    }.navDestination(this.routerMap)
  }
}