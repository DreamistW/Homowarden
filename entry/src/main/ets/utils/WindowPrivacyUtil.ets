import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';
import { SCREEN_CAPTURE_PROTECTION } from './Constants';
import { CredentialStore } from './CredentialStore';

export class WindowPrivacyUtil {
  private static store: preferences.Preferences | undefined = undefined;
  private static initialization: Promise<void> | undefined = undefined;
  private static windowUpdate: Promise<boolean> = Promise.resolve(false);

  static initialize(context: common.Context): Promise<void> {
    if (!WindowPrivacyUtil.initialization) {
      WindowPrivacyUtil.initialization = WindowPrivacyUtil.openPreferences(context).catch((error: Error) => {
        WindowPrivacyUtil.initialization = undefined;
        WindowPrivacyUtil.logError('init screen capture protection preference', error);
        throw error;
      });
    }
    return WindowPrivacyUtil.initialization;
  }

  private static async openPreferences(context: common.Context): Promise<void> {
    // 沿用原文件和键，保留已保存的开关；不依赖第三方 init() 的异步回调时序。
    const store = await preferences.getPreferences(context, { name: 'harmonyPreferences' });
    if (!store.hasSync(SCREEN_CAPTURE_PROTECTION)) {
      store.putSync(SCREEN_CAPTURE_PROTECTION, 1);
      await store.flush();
    }
    WindowPrivacyUtil.store = store;
    Logger.info('Screen capture protection preferences ready');
  }

  static isScreenCaptureProtectionEnabled(): boolean {
    if (!WindowPrivacyUtil.store) {
      return true;
    }
    try {
      return WindowPrivacyUtil.store.getSync(SCREEN_CAPTURE_PROTECTION, 1) !== 0;
    } catch (error) {
      WindowPrivacyUtil.logError('read screen capture protection preference', error as Object);
      return true;
    }
  }

  static async setScreenCaptureProtectionEnabled(enabled: boolean): Promise<boolean> {
    try {
      await WindowPrivacyUtil.initialization;
    } catch (error) {
      return false;
    }
    const store = WindowPrivacyUtil.store;
    if (!store) {
      Logger.error('Failed to save screen capture protection preference. Code: unavailable, message: Store is not ready');
      return false;
    }
    let saved = false;
    try {
      store.putSync(SCREEN_CAPTURE_PROTECTION, enabled ? 1 : 0);
      await store.flush();
      saved = true;
    } catch (error) {
      WindowPrivacyUtil.logError('save screen capture protection preference', error as Object);
    }
    // 即使落盘失败，也应用内存中的选择，确保开启保护不会被持久化错误阻断。
    const applied = await WindowPrivacyUtil.applyForCurrentState();
    return saved && applied;
  }

  static applyForCurrentState(): Promise<boolean> {
    // 执行时再读取状态，避免较早的异步更新覆盖用户刚修改的设置。
    const update = WindowPrivacyUtil.windowUpdate.then(() => {
      return WindowPrivacyUtil.setWindowPrivacyMode(WindowPrivacyUtil.shouldProtectWindow());
    });
    WindowPrivacyUtil.windowUpdate = update;
    return update;
  }

  private static async setWindowPrivacyMode(isPrivacyMode: boolean): Promise<boolean> {
    try {
      const windowStage = AppStorage.get('windowStage') as window.WindowStage | undefined;
      if (!windowStage) {
        Logger.info('WindowStage is unavailable when applying privacy window mode.');
        return false;
      }

      const mainWindow = await windowStage.getMainWindow();
      const windowProperties = mainWindow.getWindowProperties();
      if (windowProperties.isPrivacyMode === isPrivacyMode) {
        return true;
      }

      await mainWindow.setWindowPrivacyMode(isPrivacyMode);
      Logger.info(`Window privacy mode set to ${isPrivacyMode}.`);
      return true;
    } catch (error) {
      WindowPrivacyUtil.logError('set window privacy mode', error as Object);
      return false;
    }
  }

  private static shouldProtectWindow(): boolean {
    if (!WindowPrivacyUtil.store) {
      return true;
    }
    try {
      return CredentialStore.isLoggedInSync() && WindowPrivacyUtil.isScreenCaptureProtectionEnabled();
    } catch (error) {
      // 初始化期间也保护窗口，避免存储尚未就绪时关闭隐私保护。
      return true;
    }
  }

  private static logError(operation: string, error: Object): void {
    const details = error as BusinessError;
    Logger.error(`Failed to ${operation}. Code: ${details.code ?? 'unknown'}, message: ${details.message ?? 'Unknown error'}`);
  }
}
