import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { DataPreferences } from '@abner/datastore';
import { Logger } from '@nzy/logger';
import { ANTI_PEEP_GUIDE_SHOWN, ANTI_PEEP_PROTECTION } from './Constants';
import { FormFactorUtil } from './FormFactorUtil';

/** 协调应用偏好、系统防窥开关和遮罩订阅，PC 端不启用该能力 */
export class AntiPeepUtil {
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
    if (!AntiPeepUtil.isLocalProtectionEnabled()) {
      return false;
    }
    return await AntiPeepUtil.isSystemSwitchOn();
  }

  static resetMaskState(): void {
    AntiPeepUtil.hasShownMask = false;
  }

  static dispose(): void {
    AntiPeepUtil.unsubscribe();
  }

  private static isSupported(): boolean {
    return !FormFactorUtil.isPc();
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
    try {
      return await dlpAntiPeep.isDlpAntiPeepSwitchOn();
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Failed to get anti peep switch status. Code: ${businessError.code}, message: ${businessError.message}`);
      return false;
    }
  }

  private static async requestSystemProtection(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const result = await dlpAntiPeep.requestAntiPeepOptions(context);
      return result === dlpAntiPeep.AntiPeepOptionsResult.SUCCESS ||
        result === dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON;
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Failed to request anti peep options. Code: ${businessError.code}, message: ${businessError.message}`);
      return false;
    }
  }

  private static subscribe(): void {
    if (AntiPeepUtil.subscribed) {
      return;
    }

    try {
      dlpAntiPeep.on('dlpAntiPeep', AntiPeepUtil.statusChangeCallback);
      AntiPeepUtil.subscribed = true;
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Failed to subscribe DlpAntiPeep. Code: ${businessError.code}, message: ${businessError.message}`);
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
      const businessError = error as BusinessError;
      Logger.error(`Failed to unsubscribe DlpAntiPeep. Code: ${businessError.code}, message: ${businessError.message}`);
    }
  }

  private static async handleStatusChange(status: dlpAntiPeep.DlpAntiPeepStatus): Promise<void> {
    if (!AntiPeepUtil.isLocalProtectionEnabled()) {
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
      const businessError = error as BusinessError;
      Logger.error(`Failed to set AntiPeep MaskLayer. Code: ${businessError.code}, message: ${businessError.message}`);
    }
  }
}
