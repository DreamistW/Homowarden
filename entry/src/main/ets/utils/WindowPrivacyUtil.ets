import { window } from '@kit.ArkUI';
import { DataPreferences } from '@abner/datastore';
import { Logger } from '@nzy/logger';
import { LOGIN_STATUS_KEY, SCREEN_CAPTURE_PROTECTION } from './Constants';

/** 管理禁止截屏录屏的窗口隐私模式；该能力不负责 DLP 旁观者检测。 */
export class WindowPrivacyUtil {
  /** 首次使用时将截屏保护偏好初始化为开启，存储失败只记录日志。 */
  static ensureScreenCaptureProtectionDefault(): void {
    try {
      if (!DataPreferences.getInstance().hasSync(SCREEN_CAPTURE_PROTECTION)) {
        DataPreferences.getInstance().putSync(SCREEN_CAPTURE_PROTECTION, 1);
      }
    } catch (error) {
      Logger.error(`Failed to init screen capture protection preference. Error: ${JSON.stringify(error)}`);
    }
  }

  /** @returns 用户偏好是否开启；读取失败时按安全优先策略返回 `true`。 */
  static isScreenCaptureProtectionEnabled(): boolean {
    WindowPrivacyUtil.ensureScreenCaptureProtectionDefault();
    try {
      return DataPreferences.getInstance().getSync<number>(SCREEN_CAPTURE_PROTECTION) !== 0;
    } catch (error) {
      Logger.error(`Failed to read screen capture protection preference. Error: ${JSON.stringify(error)}`);
      return true;
    }
  }

  /**
   * 保存截屏保护偏好并立即按当前登录状态应用到主窗口。
   * @returns 偏好写入且窗口模式成功应用时为 `true`；错误均转换为 `false`。
   */
  static async setScreenCaptureProtectionEnabled(enabled: boolean): Promise<boolean> {
    try {
      DataPreferences.getInstance().putSync(SCREEN_CAPTURE_PROTECTION, enabled ? 1 : 0);
    } catch (error) {
      Logger.error(`Failed to save screen capture protection preference. Error: ${JSON.stringify(error)}`);
      return false;
    }
    return await WindowPrivacyUtil.applyForCurrentState();
  }

  /** 仅在已登录且用户开启保护时启用窗口隐私模式。 */
  static async applyForCurrentState(): Promise<boolean> {
    const shouldProtect =
      WindowPrivacyUtil.isLoggedIn() && WindowPrivacyUtil.isScreenCaptureProtectionEnabled();
    return await WindowPrivacyUtil.setWindowPrivacyMode(shouldProtect);
  }

  /**
   * 幂等设置当前主窗口的隐私模式。
   * @returns 窗口存在且已处于目标状态或设置成功时为 `true`。
   */
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
      return DataPreferences.getInstance().getSync<number>(LOGIN_STATUS_KEY) === 1;
    } catch (error) {
      Logger.error(`Failed to read login status for window privacy mode. Error: ${JSON.stringify(error)}`);
      return false;
    }
  }
}
