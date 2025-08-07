import { DataPreferences } from '@abner/datastore';
import { LOGIN_STATUS_KEY, PRIVACY_AGREED_KEY } from '../utils/Constants';
import { common } from '@kit.AbilityKit';
import { EntryRouter } from '../../../../EntryRouter';
import { DatabaseUtil } from '../utils/DatabaseUtil';

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
  pathInfos: NavPathStack = new NavPathStack();
  @State private showPrivacyDialog: boolean = true;
  private isLogin: boolean = false;

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

  onPrivacyRejected() {
    (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
  }

  onPrivacyAgreed() {
    DataPreferences.getInstance().putSync(PRIVACY_AGREED_KEY, 1);
    DatabaseUtil.getInstance().createTable();
    this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
  }

  build() {
    Navigation(this.pathInfos) {
    }
    .width('100%')
    .mode(NavigationMode.Stack)
    .onAppear(() => {
      this.getLoginStatus();
      this.getPrivacyStatus();
      if (this.showPrivacyDialog) {
        this.privacyDialogController.open();
      } else {
        this.getLoginStatus();
        if (!this.isLogin) {
          this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
        } else {
          this.pathInfos.pushPath({ name: EntryRouter.VaultPage });
        }
      }
    })
  }
}