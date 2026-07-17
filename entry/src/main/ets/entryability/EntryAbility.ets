import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { IBestInit } from '@ibestservices/ibest-ui';
import { DataPreferences } from '@abner/datastore';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';

const DOMAIN = 0x0000;
const APP_COLOR_MODE_KEY = 'appColorMode';

/**
 * 应用主 Ability：初始化偏好与两套数据库、保存 WindowStage、恢复窗口隐私模式并加载首页。
 */
export default class EntryAbility extends UIAbility {
  /**
   * 建立应用级颜色模式、偏好和数据库基础设施。
   * 数据库初始化为异步调用，当前生命周期方法不等待其完成。
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    this.updateAppColorMode();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    DataPreferences.getInstance().init(this.context);
    try {
      DatabaseUtil.init(this.context);
      ShareDatabaseUtil.init(this.context);
    } catch (err) {
      console.error(`Failed to init database. Error: ${JSON.stringify(err)}`);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  /** 保存主 WindowStage，异步恢复截屏保护，并在首页加载后初始化 UI 组件库。 */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    AppStorage.setOrCreate('windowStage', windowStage);
    void WindowPrivacyUtil.applyForCurrentState();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      IBestInit(windowStage, this.context);
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    this.updateAppColorMode(newConfig);
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  /** 将系统配置中的颜色模式发布到 AppStorage，供页面响应主题变化。 */
  private updateAppColorMode(configuration?: Configuration): void {
    const colorMode = configuration?.colorMode ?? this.context.resourceManager.getConfigurationSync().colorMode;
    AppStorage.setOrCreate(APP_COLOR_MODE_KEY, colorMode);
  }
}
