import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { DataPreferences } from '@abner/datastore';
import { Logger } from '@nzy/logger';
import { ANTI_PEEP_GUIDE_SHOWN, ANTI_PEEP_PROTECTION } from './Constants';

/**
 * 管理系统 DLP 防窥开关、状态订阅与遮罩层。
 *
 * 该能力根据旁观者检测结果遮挡窗口，与禁止截屏的窗口隐私模式相互独立。
 */
export class AntiPeepUtil {
  /** 是否已向系统注册状态回调，避免重复订阅。 */
  private static subscribed: boolean = false;
  /** 当前 HIDE 状态是否已设置遮罩，避免重复调用平台接口。 */
  private static hasShownMask: boolean = false;
  private static readonly statusChangeCallback: (status: dlpAntiPeep.DlpAntiPeepStatus) => void =
    (status: dlpAntiPeep.DlpAntiPeepStatus) => {
      void AntiPeepUtil.handleStatusChange(status);
    };

  /** 在首次使用时建立默认开启的本地偏好；存储失败只记录日志。 */
  static ensureDefaults(): void {
    try {
      if (!DataPreferences.getInstance().hasSync(ANTI_PEEP_PROTECTION)) {
        DataPreferences.getInstance().putSync(ANTI_PEEP_PROTECTION, 1);
      }
    } catch (error) {
      Logger.error(`Failed to init anti peep preferences. Error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 在 Ability 启动时恢复本地策略、系统开关和事件订阅。
   * 首次发现系统能力未开启时只引导一次；平台异常在内部转换为关闭状态。
   */
  static async initializeFromStartup(context: common.UIAbilityContext): Promise<void> {
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

    AntiPeepUtil.markGuideShown();
    await AntiPeepUtil.setProtectionEnabled(true, context);
  }

  /**
   * 更新本地防窥策略，并在需要时请求开启系统能力。
   * @param enabled `false` 时仅关闭本地策略并退订；`true` 时确保系统开关可用。
   * @param context 系统开关尚未开启时用于展示授权界面；缺失时启用失败。
   * @returns 本地策略最终是否启用，平台和存储异常不会向外抛出。
   */
  static async setProtectionEnabled(enabled: boolean, context?: common.UIAbilityContext): Promise<boolean> {
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

  /** @returns 本地策略和系统开关同时开启时为 `true`。 */
  static async isProtectionActive(): Promise<boolean> {
    AntiPeepUtil.ensureDefaults();
    if (!AntiPeepUtil.isLocalProtectionEnabled()) {
      return false;
    }
    return await AntiPeepUtil.isSystemSwitchOn();
  }

  static resetMaskState(): void {
    AntiPeepUtil.hasShownMask = false;
  }

  /** Ability 销毁时解除系统监听并清除遮罩去重状态。 */
  static dispose(): void {
    AntiPeepUtil.unsubscribe();
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

  /** 根据 DLP 状态清除去重标记或为当前主窗口设置遮罩。 */
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
