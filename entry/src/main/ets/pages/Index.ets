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
import { common } from '@kit.AbilityKit';
import { EntryRouter } from '../../../../EntryRouter';
import { Logger } from '@nzy/logger';
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

  /** 恢复 DLP 防窥策略，并按需订阅系统状态。 */
  async aboutToAppear() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await AntiPeepUtil.initializeFromStartup(context);
  }

  /** 关闭隐私弹窗并解除 DLP 监听，避免页面离开后继续操作窗口。 */
  aboutToDisappear(): void {
    this.privacyDialogController.close();
    AntiPeepUtil.dispose();
  }

  /**
   * 页面回到前台时刷新登录状态、窗口隐私和自动锁定判断，并注册前后台遮罩监听。
   */
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

  /** 记录进入后台的秒级时间戳，供下次前台判断两分钟自动锁定。 */
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
    this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
  }

  /**
   * 初始化安全偏好并选择首个路由：首次使用展示隐私确认，未登录进入登录页，已登录进入解锁页。
   */
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
