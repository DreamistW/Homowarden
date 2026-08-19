import { DataPreferences } from '@abner/datastore';
import {
  AUTO_LOCK_TIMEOUT,
  AutoLockTimeout,
  BACKGROUND_TIMESTAMP,
  BIOMETRIC_AUTH,
  LOGIN_STATUS_KEY,
  PRIVACY_AGREED_KEY,
  SCREEN_CAPTURE_PROTECTION,
  SAVE_EMAIL
} from '../utils/Constants';
import { common, Want } from '@kit.AbilityKit';
import { EntryRouter } from '../../../../EntryRouter';
import { Logger } from '@nzy/logger';
import { AppToast } from '../utils/AppToast';
import { HdsNavigation } from '@kit.UIDesignKit';
import { window } from '@kit.ArkUI';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { AntiPeepUtil } from '../utils/AntiPeepUtil';
import { BreakpointUtil } from '../utils/BreakpointUtil';
import { AutoLockUtil } from '../utils/AutoLockUtil';

@CustomDialog
struct PrivacyDialogContent {
  dialogController?: CustomDialogController
  cancel: () => void = () => {
  }
  confirm: () => void = () => {
  }

  build() {
    Column() {
      Column() {
        Text($r('app.string.privacy_welcome'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 12 })

        Text() {
          Span($r('app.string.privacy_intro_brand'))
          Span($r('app.string.privacy_storage_notice'))
          Span($r('app.string.privacy_read_prefix'))
          Span($r('app.string.privacy_policy'))
            .fontColor(Color.Blue)
            .decoration({ type: TextDecorationType.Underline })
            .onClick(() => {
              const context = getContext(this) as common.UIAbilityContext;
              const want: Want = {
                uri: 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?agreementId=1846508510607638400'
              };
              context.startAbility(want).catch((err: Error) => {
                Logger.error(`Failed to open url. Error: ${err.message}`);
                AppToast.show(this.getUIContext(), $r('app.string.error_open_website'));
              });
            })
        }
        .fontSize(16)
      }
      .padding({ left: 24, right: 24, top: 24, bottom: 16 })

      Divider()

      Row() {
        Button($r('app.string.privacy_disagree'))
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => {
            this.dialogController?.close();
            this.cancel();
          })
        Button($r('app.string.privacy_agree'))
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontColor($r('app.color.button_background_color'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => {
            this.dialogController?.close();
            this.confirm();
          })
      }
    }
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
    BreakpointUtil.dispose();
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
      const autoLockTimeoutSeconds = AutoLockUtil.getTimeoutSeconds();
      if (autoLockTimeoutSeconds !== AutoLockTimeout.NEVER) {
        const currentTime = Math.floor(Date.now() / 1000);
        const backgroundTime = DataPreferences.getInstance().getSync<number>(BACKGROUND_TIMESTAMP);
        if (currentTime - backgroundTime >= autoLockTimeoutSeconds) {
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
    alignment: DialogAlignment.Center,
    customStyle: false
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

  private initAppEntry() {
    if (!DataPreferences.getInstance().hasSync(SAVE_EMAIL)) {
      DataPreferences.getInstance().putSync(SAVE_EMAIL, 0);
    }
    if (!DataPreferences.getInstance().hasSync(BIOMETRIC_AUTH)) {
      DataPreferences.getInstance().putSync(BIOMETRIC_AUTH, 0);
    }
    if (!DataPreferences.getInstance().hasSync(AUTO_LOCK_TIMEOUT)) {
      DataPreferences.getInstance().putSync(AUTO_LOCK_TIMEOUT, AutoLockTimeout.NEVER);
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
    // 直接使用 ArkUI 实际布局尺寸，兼容媒体方向上报不准确的折叠屏形态。
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      BreakpointUtil.updateViewport(Number(newValue.width), Number(newValue.height));
    })
    .foregroundBlurStyle(this.showPrivacyMask ? BlurStyle.Thick : BlurStyle.NONE)
  }
}
