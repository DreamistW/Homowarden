import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { DataPreferences } from '@abner/datastore';
import { Logger } from '@nzy/logger';
import { ANTI_PEEP_GUIDE_SHOWN, ANTI_PEEP_PROTECTION } from './Constants';

/** 按设备实际能力协调应用偏好、系统防窥开关和遮罩订阅。 */
export class AntiPeepUtil {
  private static capabilitySupported: boolean | undefined = undefined;
  private static switchStatusPromise: Promise<boolean> | undefined = undefined;
  private static subscribed: boolean = false;
  private static hasShownMask: boolean = false;
  private static readonly statusChangeCallback: (status: dlpAntiPeep.DlpAntiPeepStatus) => void =
    (status: dlpAntiPeep.DlpAntiPeepStatus) => {
      void AntiPeepUtil.handleStatusChange(status);
    };

  static ensureDefaults(): void {
    if (!AntiPeepUtil.isSupported()) {
      return;
    }

    try {
      if (!DataPreferences.getInstance().hasSync(ANTI_PEEP_PROTECTION)) {
        DataPreferences.getInstance().putSync(ANTI_PEEP_PROTECTION, 1);
      }
    } catch (error) {
      Logger.error(`Failed to init anti peep preferences. Error: ${JSON.stringify(error)}`);
    }
  }

  static async initializeFromStartup(context: common.UIAbilityContext): Promise<void> {
    if (!AntiPeepUtil.isSupported()) {
      AntiPeepUtil.unsubscribe();
      return;
    }

    AntiPeepUtil.ensureDefaults();
    if (!AntiPeepUtil.isLocalProtectionEnabled()) {
      AntiPeepUtil.unsubscribe();
      return;
    }

    const isOpen = await AntiPeepUtil.isSystemSwitchOn();
    if (!AntiPeepUtil.isSupported()) {
      return;
    }
    if (isOpen) {
      AntiPeepUtil.subscribe();
      return;
    }

    if (AntiPeepUtil.hasGuideShown()) {
      AntiPeepUtil.unsubscribe();
      return;
    }

    // 系统授权引导只主动展示一次，后续由用户在设置页显式开启
    AntiPeepUtil.markGuideShown();
    await AntiPeepUtil.setProtectionEnabled(true, context);
  }

  static async setProtectionEnabled(enabled: boolean, context?: common.UIAbilityContext): Promise<boolean> {
    if (!AntiPeepUtil.isSupported()) {
      AntiPeepUtil.unsubscribe();
      return false;
    }

    AntiPeepUtil.ensureDefaults();
    if (!enabled) {
      AntiPeepUtil.saveLocalProtectionEnabled(false);
      AntiPeepUtil.unsubscribe();
      return true;
    }

    if (await AntiPeepUtil.isSystemSwitchOn()) {
      AntiPeepUtil.saveLocalProtectionEnabled(true);
      AntiPeepUtil.subscribe();
      return true;
    }

    // 系统能力声明存在时，具体硬件仍可能返回 801，不能再请求开启。
    if (!AntiPeepUtil.isSupported()) {
      return false;
    }

    if (!context) {
      AntiPeepUtil.saveLocalProtectionEnabled(false);
      AntiPeepUtil.unsubscribe();
      return false;
    }

    const isEnabled = await AntiPeepUtil.requestSystemProtection(context);
    AntiPeepUtil.saveLocalProtectionEnabled(isEnabled);
    if (isEnabled) {
      AntiPeepUtil.subscribe();
    } else {
      AntiPeepUtil.unsubscribe();
    }
    return isEnabled;
  }

  static async isProtectionActive(): Promise<boolean> {
    if (!AntiPeepUtil.isSupported()) {
      return false;
    }

    AntiPeepUtil.ensureDefaults();
    // 即使本地开关已关闭，也探测实际硬件能力，供设置页正确置灰。
    const isOpen = await AntiPeepUtil.isSystemSwitchOn();
    return isOpen && AntiPeepUtil.isLocalProtectionEnabled();
  }

  static resetMaskState(): void {
    AntiPeepUtil.hasShownMask = false;
  }

  static dispose(): void {
    AntiPeepUtil.unsubscribe();
  }

  static isSupported(): boolean {
    if (AntiPeepUtil.capabilitySupported === undefined) {
      AntiPeepUtil.capabilitySupported = canIUse('SystemCapability.Security.DlpAntiPeep');
      Logger.info(`[AntiPeep] canIUse(SystemCapability.Security.DlpAntiPeep)=${AntiPeepUtil.capabilitySupported}`);
    }
    return AntiPeepUtil.capabilitySupported;
  }

  private static logApiError(operation: string, error: BusinessError): void {
    if (error.code === 801) {
      if (AntiPeepUtil.capabilitySupported !== false) {
        Logger.info(`[AntiPeep] ${operation}: capability unsupported (801); further calls disabled`);
      }
      AntiPeepUtil.capabilitySupported = false;
      return;
    }
    Logger.error(`Failed to ${operation}. Code: ${error.code}, message: ${error.message}`);
  }

  private static isLocalProtectionEnabled(): boolean {
    try {
      return DataPreferences.getInstance().getSync<number>(ANTI_PEEP_PROTECTION) !== 0;
    } catch (error) {
      Logger.error(`Failed to read anti peep preference. Error: ${JSON.stringify(error)}`);
      return true;
    }
  }

  private static saveLocalProtectionEnabled(enabled: boolean): void {
    try {
      DataPreferences.getInstance().putSync(ANTI_PEEP_PROTECTION, enabled ? 1 : 0);
    } catch (error) {
      Logger.error(`Failed to save anti peep preference. Error: ${JSON.stringify(error)}`);
    }
  }

  private static hasGuideShown(): boolean {
    try {
      return DataPreferences.getInstance().getSync<number>(ANTI_PEEP_GUIDE_SHOWN) === 1;
    } catch (error) {
      Logger.error(`Failed to read anti peep guide preference. Error: ${JSON.stringify(error)}`);
      return true;
    }
  }

  private static markGuideShown(): void {
    try {
      DataPreferences.getInstance().putSync(ANTI_PEEP_GUIDE_SHOWN, 1);
    } catch (error) {
      Logger.error(`Failed to save anti peep guide preference. Error: ${JSON.stringify(error)}`);
    }
  }

  private static async isSystemSwitchOn(): Promise<boolean> {
    if (!AntiPeepUtil.isSupported()) {
      return false;
    }
    if (AntiPeepUtil.switchStatusPromise) {
      return await AntiPeepUtil.switchStatusPromise;
    }
    const request = AntiPeepUtil.readSystemSwitch();
    AntiPeepUtil.switchStatusPromise = request;
    try {
      return await request;
    } finally {
      if (AntiPeepUtil.switchStatusPromise === request) {
        AntiPeepUtil.switchStatusPromise = undefined;
      }
    }
  }

  private static async readSystemSwitch(): Promise<boolean> {
    try {
      return await dlpAntiPeep.isDlpAntiPeepSwitchOn();
    } catch (error) {
      AntiPeepUtil.logApiError('get anti peep switch status', error as BusinessError);
      return false;
    }
  }

  private static async requestSystemProtection(context: common.UIAbilityContext): Promise<boolean> {
    if (!AntiPeepUtil.isSupported()) {
      return false;
    }
    try {
      const result = await dlpAntiPeep.requestAntiPeepOptions(context);
      return result === dlpAntiPeep.AntiPeepOptionsResult.SUCCESS ||
        result === dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON;
    } catch (error) {
      AntiPeepUtil.logApiError('request anti peep options', error as BusinessError);
      return false;
    }
  }

  private static subscribe(): void {
    if (!AntiPeepUtil.isSupported() || AntiPeepUtil.subscribed) {
      return;
    }

    try {
      dlpAntiPeep.on('dlpAntiPeep', AntiPeepUtil.statusChangeCallback);
      AntiPeepUtil.subscribed = true;
    } catch (error) {
      AntiPeepUtil.logApiError('subscribe DlpAntiPeep', error as BusinessError);
    }
  }

  private static unsubscribe(): void {
    if (!AntiPeepUtil.subscribed) {
      return;
    }

    try {
      dlpAntiPeep.off('dlpAntiPeep', AntiPeepUtil.statusChangeCallback);
      AntiPeepUtil.subscribed = false;
      AntiPeepUtil.hasShownMask = false;
    } catch (error) {
      AntiPeepUtil.logApiError('unsubscribe DlpAntiPeep', error as BusinessError);
    }
  }

  private static async handleStatusChange(status: dlpAntiPeep.DlpAntiPeepStatus): Promise<void> {
    if (!AntiPeepUtil.isSupported() || !AntiPeepUtil.isLocalProtectionEnabled()) {
      return;
    }

    if (status === dlpAntiPeep.DlpAntiPeepStatus.PASS) {
      AntiPeepUtil.hasShownMask = false;
      Logger.info('DlpAntiPeepStatus is PASS.');
      return;
    }

    if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) {
      Logger.info('DlpAntiPeepStatus is HIDE.');
      // 同一轮遮挡只设置一次遮罩，等待 PASS 后再允许下一次设置
      if (!AntiPeepUtil.hasShownMask) {
        await AntiPeepUtil.setMaskLayer();
      }
    }
  }

  private static async setMaskLayer(): Promise<void> {
    if (!AntiPeepUtil.isSupported()) {
      return;
    }
    try {
      const windowStage = AppStorage.get('windowStage') as window.WindowStage | undefined;
      if (!windowStage) {
        Logger.info('WindowStage is unavailable when setting anti peep mask layer.');
        return;
      }

      const mainWindow = await windowStage.getMainWindow();
      const windowId = mainWindow.getWindowProperties().id;
      await dlpAntiPeep.setAntiPeepMaskLayer(windowId);
      AntiPeepUtil.hasShownMask = true;
    } catch (error) {
      AntiPeepUtil.logApiError('set AntiPeep MaskLayer', error as BusinessError);
    }
  }
}
