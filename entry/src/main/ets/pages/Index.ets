import { DataPreferences } from '@abner/datastore';
import {
  AUTO_LOCK,
  BACKGROUND_TIMESTAMP,
  BIOMETRIC_AUTH,
  LOGIN_STATUS_KEY,
  PRIVACY_AGREED_KEY,
  SAVE_EMAIL
} from '../utils/Constants';
import { common, Want } from '@kit.AbilityKit';
import { EntryRouter } from '../../../../EntryRouter';
import { DatabaseUtil } from '../utils/DatabaseUtil';

@CustomDialog
struct PrivacyDialogContent {
  dialogController?: CustomDialogController
  cancel: () => void = () => {
  }
  confirm: () => void = () => {
  }

  build() {
    Column() {
      Text("隐私政策")
        .fontSize(20)
        .margin({ top: 20, bottom: 10 })

      Text() {
        Span('请仔细阅读并同意')
        Span('隐私政策')
          .fontColor(Color.Blue)
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => {
          })
      }
      .fontSize(16)
      .margin({ bottom: 20 })

      Row() {
        Button('不同意')
          .onClick(() => {
            this.dialogController?.close();
            this.cancel();
          })
          .margin({ right: 12 })
        Button('同意')
          .onClick(() => {
            this.dialogController?.close();
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
      if (!DataPreferences.getInstance().hasSync(SAVE_EMAIL)) {
        DataPreferences.getInstance().putSync(SAVE_EMAIL, 0);
      }
      if (!DataPreferences.getInstance().hasSync(BIOMETRIC_AUTH)) {
        DataPreferences.getInstance().putSync(BIOMETRIC_AUTH, 0);
      }
      if (!DataPreferences.getInstance().hasSync(AUTO_LOCK)) {
        DataPreferences.getInstance().putSync(AUTO_LOCK, 0);
      }
      DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
      this.getLoginStatus();
      this.getPrivacyStatus();
      if (this.showPrivacyDialog) {
        this.privacyDialogController.open();
      } else {
        this.getLoginStatus();
        if (!this.isLogin) {
          this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
        } else {
          // 判断是否开启生物识别
          const result = DataPreferences.getInstance().getSync<number>(BIOMETRIC_AUTH);
          if (result == 1) {
            this.pathInfos.pushPath({ name: EntryRouter.BiometricAuthPage });
          } else {
            this.pathInfos.pushPath({ name: EntryRouter.VaultPage });
          }
        }
      }
    })
  }
}