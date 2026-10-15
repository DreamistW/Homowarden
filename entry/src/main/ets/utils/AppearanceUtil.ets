import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';
import { Logger } from '@nzy/logger';

export enum InterfaceLanguage {
  SYSTEM = 0,
  CHINESE = 1,
  ENGLISH = 2
}

export enum InterfaceColor {
  SYSTEM = 0,
  LIGHT = 1,
  DARK = 2
}

const LANGUAGE_KEY = 'interface_language';
const COLOR_KEY = 'interface_color';

/** 外观是设备上的应用偏好，不随账户退出而清除。 */
export class AppearanceUtil {
  private static store?: preferences.Preferences;

  static initialize(context: common.Context): void {
    // 同步打开，保证窗口首次加载时就能读取上次的选择。
    AppearanceUtil.store = preferences.getPreferencesSync(context, { name: 'appearance' });
  }

  static getLanguage(): InterfaceLanguage {
    const value = AppearanceUtil.readPreference(LANGUAGE_KEY);
    return value === InterfaceLanguage.CHINESE || value === InterfaceLanguage.ENGLISH ? value : InterfaceLanguage.SYSTEM;
  }

  static getColor(): InterfaceColor {
    const value = AppearanceUtil.readPreference(COLOR_KEY);
    return value === InterfaceColor.LIGHT || value === InterfaceColor.DARK ? value : InterfaceColor.SYSTEM;
  }

  static async setLanguage(value: InterfaceLanguage): Promise<void> {
    const language = value === InterfaceLanguage.CHINESE ? 'zh-Hans' :
      (value === InterfaceLanguage.ENGLISH ? 'en' : 'default');
    // 系统持久化应用偏好语言；default 恢复跟随系统在下次冷启动生效。
    i18n.System.setAppPreferredLanguage(language);
    await AppearanceUtil.savePreference(LANGUAGE_KEY, value);
  }

  static async setColor(context: common.Context, value: InterfaceColor): Promise<void> {
    AppearanceUtil.applyColor(context, value);
    await AppearanceUtil.savePreference(COLOR_KEY, value);
  }

  static restoreColor(context: common.Context): void {
    try {
      AppearanceUtil.applyColor(context, AppearanceUtil.getColor());
    } catch (error) {
      Logger.error(`Failed to restore interface color: ${JSON.stringify(error)}`);
    }
  }

  private static applyColor(context: common.Context, value: InterfaceColor): void {
    const colorMode = value === InterfaceColor.LIGHT ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT :
      (value === InterfaceColor.DARK ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    context.getApplicationContext().setColorMode(colorMode);
  }

  private static readPreference(key: string): number {
    try {
      return AppearanceUtil.store?.getSync(key, 0) as number ?? 0;
    } catch (error) {
      Logger.error(`Failed to load appearance preference: ${JSON.stringify(error)}`);
      return 0;
    }
  }

  private static async savePreference(key: string, value: number): Promise<void> {
    if (!AppearanceUtil.store) {
      throw new Error('Appearance preferences are unavailable');
    }
    AppearanceUtil.store.putSync(key, value);
    await AppearanceUtil.store.flush();
  }
}
