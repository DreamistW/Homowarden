import { DataPreferences } from '@abner/datastore';
import {
  AUTO_LOCK_TIMEOUT,
  AutoLockTimeout,
  BIOMETRIC_AUTH,
  SAVE_EMAIL
} from '../utils/Constants';
import { common } from '@kit.AbilityKit';
import { EntryRouter } from '../../../../EntryRouter';
import { Logger } from '@nzy/logger';
import { window } from '@kit.ArkUI';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { BreakpointUtil } from '../utils/BreakpointUtil';
import { AutoLockUtil } from '../utils/AutoLockUtil';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { CredentialStore } from '../utils/CredentialStore';
import { CredentialStorageError, CredentialStorageFailure } from '../utils/CredentialStorageError';
import { ConfirmDialog } from '../component/ConfirmDialog';

/** 统筹顶层导航、隐私遮罩与全局空闲锁定 */
@Entry
@Component
struct Index {
  pathInfos: NavPathStack = new NavPathStack();
  @State private showPrivacyMask: boolean = false;
  @State private hasInitializedRoute: boolean = false;
  @State private credentialInitializationFailed: boolean = false;
  @State private credentialBusy: boolean = false;
  @State private credentialFailureReason: ResourceStr = '';
  @State private credentialFailureCode: number = 0;
  @State private repairTitle: ResourceStr = $r('app.string.storage_repair_title');
  @State private repairMessage: ResourceStr = $r('app.string.storage_repair_message');
  @State private repairConfirmText: ResourceStr = $r('app.string.storage_repair_confirm');
  private isLogin: boolean = false;
  private autoLockTimer: number = -1;
  private repairDialogController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: $repairTitle,
      message: $repairMessage,
      confirmText: $repairConfirmText,
      onConfirm: async (): Promise<boolean> => {
        await this.repairCredentialStorage();
        return true;
      }
    }),
    autoCancel: true,
    onWillDismiss: (action: DismissDialogAction): void => {
      if (!this.credentialBusy) {
        action.dismiss();
      }
    },
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  async aboutToAppear() {
    this.startAutoLockWatcher();
  }

  aboutToDisappear(): void {
    this.repairDialogController.close();
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

  getLoginStatus() {
    try {
      this.isLogin = CredentialStore.isLoggedInSync();
    } catch (_) {
      this.isLogin = false;
    }
  }

  private async initAppEntry(): Promise<void> {
    if (this.credentialBusy) {
      return;
    }
    this.credentialBusy = true;
    this.credentialInitializationFailed = false;
    try {
      await CredentialStore.initialize(this.getUIContext().getHostContext() as common.UIAbilityContext);
    } catch (error) {
      this.showCredentialFailure(error as Error);
      Logger.error('Credential database initialization failed; original credentials retained');
      return;
    } finally {
      this.credentialBusy = false;
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
    if (!this.isLogin) {
      this.pathInfos.pushPath({ name: EntryRouter.LoginPage });
    } else if (VaultViewModel.isSessionActive() && this.canRestoreUnlockedVault()) {
      this.pathInfos.pushPath({ name: EntryRouter.VaultPage });
    } else {
      VaultViewModel.lockSession();
      this.pathInfos.pushPath({ name: EntryRouter.UnlockPage });
    }
  }

  private showCredentialFailure(error: Error): void {
    const failure = CredentialStorageError.wrap(error, CredentialStorageFailure.PREFERENCES);
    this.credentialFailureReason = CredentialStorageError.description(failure.reason);
    this.credentialFailureCode = failure.code;
    this.credentialInitializationFailed = true;
  }

  private async repairCredentialStorage(): Promise<void> {
    if (this.credentialBusy) {
      return;
    }
    this.credentialBusy = true;
    let repaired = false;
    try {
      VaultViewModel.lockSession();
      await CredentialStore.repair(this.getUIContext().getHostContext() as common.UIAbilityContext);
      repaired = true;
    } catch (error) {
      this.showCredentialFailure(error as Error);
      Logger.error('Local credential storage repair failed');
    } finally {
      this.credentialBusy = false;
    }
    if (repaired) {
      this.pathInfos.clear();
      await this.initAppEntry();
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
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
          Text(this.credentialFailureReason)
            .textAlign(TextAlign.Center)
          if (this.credentialFailureCode !== 0) {
            Text($r('app.string.storage_error_code', this.credentialFailureCode))
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          Button($r('app.string.common_retry'))
            .enabled(!this.credentialBusy)
            .onClick(() => { void this.initAppEntry(); })
          Button(this.credentialBusy ? $r('app.string.storage_repair_progress') :
            $r('app.string.storage_repair_action'))
            .id('storage_repair_button')
            .enabled(!this.credentialBusy)
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .onClick(() => { this.repairDialogController.open(); })
        }
        .padding(24)
        .constraintSize({ maxWidth: 480 })
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
