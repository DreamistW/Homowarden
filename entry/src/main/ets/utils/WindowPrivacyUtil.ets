import { window } from '@kit.ArkUI';
import { DataPreferences } from '@abner/datastore';
import { Logger } from '@nzy/logger';
import { SCREEN_CAPTURE_PROTECTION } from './Constants';
import { CredentialStore } from './CredentialStore';

export class WindowPrivacyUtil {
  static ensureScreenCaptureProtectionDefault(): void {
    try {
      if (!DataPreferences.getInstance().hasSync(SCREEN_CAPTURE_PROTECTION)) {
        DataPreferences.getInstance().putSync(SCREEN_CAPTURE_PROTECTION, 1);
      }
    } catch (error) {
      Logger.error(`Failed to init screen capture protection preference. Error: ${JSON.stringify(error)}`);
    }
  }

  static isScreenCaptureProtectionEnabled(): boolean {
    WindowPrivacyUtil.ensureScreenCaptureProtectionDefault();
    try {
      return DataPreferences.getInstance().getSync<number>(SCREEN_CAPTURE_PROTECTION) !== 0;
    } catch (error) {
      Logger.error(`Failed to read screen capture protection preference. Error: ${JSON.stringify(error)}`);
      return true;
    }
  }

  static async setScreenCaptureProtectionEnabled(enabled: boolean): Promise<boolean> {
    try {
      DataPreferences.getInstance().putSync(SCREEN_CAPTURE_PROTECTION, enabled ? 1 : 0);
    } catch (error) {
      Logger.error(`Failed to save screen capture protection preference. Error: ${JSON.stringify(error)}`);
      return false;
    }
    return await WindowPrivacyUtil.applyForCurrentState();
  }

  static async applyForCurrentState(): Promise<boolean> {
    const shouldProtect =
      WindowPrivacyUtil.isLoggedIn() && WindowPrivacyUtil.isScreenCaptureProtectionEnabled();
    return await WindowPrivacyUtil.setWindowPrivacyMode(shouldProtect);
  }

  static async setWindowPrivacyMode(isPrivacyMode: boolean): Promise<boolean> {
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
      Logger.error(`Failed to set window privacy mode. Error: ${JSON.stringify(error)}`);
      return false;
    }
  }

  private static isLoggedIn(): boolean {
    try {
      return CredentialStore.isLoggedInSync();
    } catch (error) {
      // 初始化期间也保护窗口，避免存储尚未就绪时关闭隐私保护。
      return true;
    }
  }
}
