import { DataPreferences } from '@abner/datastore';
import {
  AUTO_LOCK_TIMEOUT,
  AutoLockTimeout,
  BIOMETRIC_AUTH,
  PRIVACY_AGREED_KEY,
  SAVE_EMAIL
} from '../utils/Constants';
import { common, Want } from '@kit.AbilityKit';
import { EntryRouter } from '../../../../EntryRouter';
import { Logger } from '@nzy/logger';
import { AppToast } from '../utils/AppToast';
import { window } from '@kit.ArkUI';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { BreakpointUtil } from '../utils/BreakpointUtil';
import { AutoLockUtil } from '../utils/AutoLockUtil';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { LocaleUtil } from '../localization/LocaleUtil';
import { CredentialStore } from '../utils/CredentialStore';

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
          Span($r('app.string.privacy_read_prefix'))
          Span($r('app.string.privacy_policy'))
            .fontColor(Color.Blue)
            .decoration({ type: TextDecorationType.Underline })
            .onClick(() => {
              const context = getContext(this) as common.UIAbilityContext;
              const want: Want = {
                uri: LocaleUtil.getPrivacyPolicyUrl()
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

/** 统筹顶层导航、隐私遮罩与全局空闲锁定 */
@Entry
@Component
struct Index {
  pathInfos: NavPathStack = new NavPathStack();
  @State private showPrivacyDialog: boolean = true;
  @State private showPrivacyMask: boolean = false;
  @State private hasInitializedRoute: boolean = false;
  @State private credentialInitializationFailed: boolean = false;
  private isLogin: boolean = false;
  private autoLockTimer: number = -1;

  async aboutToAppear() {
    this.startAutoLockWatcher();
  }

  aboutToDisappear(): void {
    this.privacyDialogController.close();
    BreakpointUtil.dispose();
    this.stopAutoLockWatcher();
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
    this.getLoginStatus();
    void WindowPrivacyUtil.applyForCurrentState();
    if (this.hasInitializedRoute && this.isLogin) {
      this.enforceAutoLockOnForeground();
    }
  }

  onPageHide(): void {
    Logger.info('Index onPageHide');
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
    try {
      this.isLogin = CredentialStore.isLoggedInSync();
    } catch (_) {
      this.isLogin = false;
    }
  }

  onPrivacyRejected() {
    (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
  }

  onPrivacyAgreed() {
    DataPreferences.getInstance().putSync(PRIVACY_AGREED_KEY, 1);
    this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
  }

  private async initAppEntry(): Promise<void> {
    this.credentialInitializationFailed = false;
    try {
      await CredentialStore.initialize(this.getUIContext().getHostContext() as common.UIAbilityContext);
    } catch (_) {
      this.credentialInitializationFailed = true;
      Logger.error('Credential database initialization failed; original credentials retained');
      return;
    }
    if (!DataPreferences.getInstance().hasSync(SAVE_EMAIL)) {
      DataPreferences.getInstance().putSync(SAVE_EMAIL, 0);
    }
    if (!DataPreferences.getInstance().hasSync(BIOMETRIC_AUTH)) {
      DataPreferences.getInstance().putSync(BIOMETRIC_AUTH, 0);
    }
    if (!DataPreferences.getInstance().hasSync(AUTO_LOCK_TIMEOUT)) {
      DataPreferences.getInstance().putSync(AUTO_LOCK_TIMEOUT, AutoLockTimeout.NEVER);
    }
    this.getLoginStatus();
    void WindowPrivacyUtil.applyForCurrentState();
    // 隐私政策已接入托管，停用应用内首次启动弹窗。
    // this.getPrivacyStatus();
    // if (this.showPrivacyDialog) {
    //   this.privacyDialogController.open();
    // }
    if (!this.isLogin) {
      this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
    } else if (VaultViewModel.isSessionActive() && this.canRestoreUnlockedVault()) {
      this.pathInfos.pushPath({ name: EntryRouter.VaultPage });
    } else {
      VaultViewModel.lockSession();
      this.pathInfos.pushPath({ name: EntryRouter.UnlockPage });
    }
  }

  private canRestoreUnlockedVault(): boolean {
    return !AutoLockUtil.hasTimedOut();
  }

  private startAutoLockWatcher(): void {
    this.stopAutoLockWatcher();
    this.autoLockTimer = setInterval(() => {
      if (VaultViewModel.isSessionActive() && AutoLockUtil.hasTimedOut()) {
        this.lockVaultForTimeout();
      }
    }, 1000);
  }

  private stopAutoLockWatcher(): void {
    if (this.autoLockTimer < 0) {
      return;
    }
    clearInterval(this.autoLockTimer);
    this.autoLockTimer = -1;
  }

  private handleUserActivity(): void {
    if (!VaultViewModel.isSessionActive()) {
      return;
    }
    // 先判定是否超时再刷新活动时间，避免超时后的首次输入绕过锁定
    if (AutoLockUtil.hasTimedOut()) {
      this.lockVaultForTimeout();
      return;
    }
    AutoLockUtil.recordActivity();
  }

  private enforceAutoLockOnForeground(): void {
    if (!VaultViewModel.isSessionActive() || AutoLockUtil.hasTimedOut()) {
      this.lockVaultForTimeout();
    }
  }

  private lockVaultForTimeout(): void {
    VaultViewModel.lockSession();
    const paths = this.pathInfos.getPathStack();
    const activePathName = paths.length > 0 ? paths[paths.length - 1].name : '';
    if (activePathName === EntryRouter.UnlockPage || activePathName === EntryRouter.LoginPage) {
      return;
    }
    this.pathInfos.pushPath({ name: EntryRouter.UnlockPage });
  }

  build() {
    Stack() {
      Navigation(this.pathInfos) {
      }
      .width('100%')
      .height('100%')
      .mode(NavigationMode.Stack)
      .onAppear(() => {
        if (this.hasInitializedRoute) {
          return;
        }
        this.hasInitializedRoute = true;
        void this.initAppEntry();
      })
      if (this.credentialInitializationFailed) {
        Column({ space: 16 }) {
          Text($r('app.string.error_storage'))
          Button($r('app.string.common_retry'))
            .onClick(() => { void this.initAppEntry(); })
        }
        .padding(24)
      }
    }
    .width('100%')
    .height('100%')
    // 直接使用 ArkUI 实际布局尺寸，兼容媒体方向上报不准确的折叠屏形态
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      BreakpointUtil.updateViewport(Number(newValue.width), Number(newValue.height));
    })
    .onTouch(() => {
      this.handleUserActivity();
    })
    .onMouse(() => {
      this.handleUserActivity();
    })
    .onKeyEvent(() => {
      this.handleUserActivity();
    })
    .foregroundBlurStyle(this.showPrivacyMask ? BlurStyle.Thick : BlurStyle.NONE)
  }
}
