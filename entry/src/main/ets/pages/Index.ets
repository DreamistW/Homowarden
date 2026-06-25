import { DataPreferences } from '@abner/datastore';
import {
  AUTO_LOCK,
  BACKGROUND_TIMESTAMP,
  BIOMETRIC_AUTH,
  LOGIN_STATUS_KEY,
  PRIVACY_AGREED_KEY,
  SCREEN_CAPTURE_PROTECTION,
  SAVE_EMAIL
} from '../utils/Constants';
import { common, Want } from '@kit.AbilityKit';
import { EntryRouter } from '../../../../EntryRouter';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { Logger } from '@nzy/logger';
import { IBestToast } from '@ibestservices/ibest-ui';
import { HdsNavigation } from '@kit.UIDesignKit';
import { window } from '@kit.ArkUI';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { AntiPeepUtil } from '../utils/AntiPeepUtil';

@CustomDialog
struct PrivacyDialogContent {
  dialogController?: CustomDialogController
  cancel: () => void = () => {
  }
  confirm: () => void = () => {
  }

  build() {
    Column() {
      Text("欢迎")
        .fontSize(20)
        .margin({ top: 20, bottom: 10 })

      Text() {
        Span('欢迎使用 Homowarden\n\n')
        Span('注意: 本应用的密钥数据存储在关键资产区域, 不会随应用卸载而清除, 卸载应用前请务必注销登录\n\n')
        Span('在开始使用之前, 请仔细阅读并同意')
        Span('隐私政策')
          .fontColor(Color.Blue)
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => {
            const context = getContext(this) as common.UIAbilityContext;
            const want: Want = {
              uri: 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1846508510607638400'
            };
            context.startAbility(want).catch((err: Error) => {
              Logger.error(`Failed to open url. Error: ${err.message}`);
              IBestToast.show(`无法打开页面, 错误信息: ${err.message}`);
            });
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
  @State private showPrivacyMask: boolean = false;
  @State private hasInitializedRoute: boolean = false;
  private isLogin: boolean = false;

  // 检查防窥保护开关并订阅通知
  async aboutToAppear() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await AntiPeepUtil.initializeFromStartup(context);
  }

  aboutToDisappear(): void {
    this.privacyDialogController.close();
    AntiPeepUtil.dispose();
  }

  onPageShow(): void {
    Logger.info('Index onPageShow');
    let windowStage = AppStorage.get('windowStage') as window.WindowStage;
    windowStage.on('windowStageEvent', (data) => {
      if (data === window.WindowStageEventType.PAUSED) {
        this.showPrivacyMask = true;
      } else {
        this.showPrivacyMask = false;
      }
    })
    AntiPeepUtil.resetMaskState();
    this.getLoginStatus();
    void WindowPrivacyUtil.applyForCurrentState();
    if (this.isLogin) {
      const autoLockStatus = DataPreferences.getInstance().getSync<number>(AUTO_LOCK);
      if (autoLockStatus == 1) {
        const currentTime = Math.floor(Date.now() / 1000);
        const backgroundTime = DataPreferences.getInstance().getSync<number>(BACKGROUND_TIMESTAMP);
        if (currentTime - backgroundTime > 120) {
          this.pathInfos.pushPath({ name: EntryRouter.UnlockPage });
        }
      }
    }
  }

  onPageHide(): void {
    Logger.info('Index onPageHide');
    DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
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

  private initAppEntry() {
    if (!DataPreferences.getInstance().hasSync(SAVE_EMAIL)) {
      DataPreferences.getInstance().putSync(SAVE_EMAIL, 0);
    }
    if (!DataPreferences.getInstance().hasSync(BIOMETRIC_AUTH)) {
      DataPreferences.getInstance().putSync(BIOMETRIC_AUTH, 0);
    }
    if (!DataPreferences.getInstance().hasSync(AUTO_LOCK)) {
      DataPreferences.getInstance().putSync(AUTO_LOCK, 0);
    }
    if (!DataPreferences.getInstance().hasSync(SCREEN_CAPTURE_PROTECTION)) {
      DataPreferences.getInstance().putSync(SCREEN_CAPTURE_PROTECTION, 1);
    }
    AntiPeepUtil.ensureDefaults();
    this.getLoginStatus();
    void WindowPrivacyUtil.applyForCurrentState();
    this.getPrivacyStatus();
    if (this.showPrivacyDialog) {
      this.privacyDialogController.open();
    } else {
      this.getLoginStatus();
      if (!this.isLogin) {
        this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
      } else {
        this.pathInfos.pushPath({ name: EntryRouter.UnlockPage });
      }
    }
  }

  build() {
    Stack() {
      HdsNavigation(this.pathInfos) {
      }
      .width('100%')
      .height('100%')
      .mode(NavigationMode.Stack)
      .onAppear(() => {
        if (this.hasInitializedRoute) {
          return;
        }
        this.hasInitializedRoute = true;
        this.initAppEntry();
      })
    }
    .width('100%')
    .height('100%')
    .foregroundBlurStyle(this.showPrivacyMask ? BlurStyle.Thick : BlurStyle.NONE)
  }
}
