import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DataPreferences } from '@abner/datastore';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { GeneratorDatabaseUtil } from '../utils/GeneratorDatabaseUtil';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { LocaleState } from '../localization/LocaleState';
import { BreakpointUtil } from '../utils/BreakpointUtil';
import { VaultChangeNotifier } from '../utils/VaultChangeNotifier';
import { SystemTrayManager } from '../utils/SystemTrayManager';
import { FormFactorUtil } from '../utils/FormFactorUtil';

const DOMAIN = 0x0000;
const PC_MIN_WINDOW_WIDTH = 840;
const PC_MIN_WINDOW_HEIGHT = 600;
export default class EntryAbility extends UIAbility {
  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, 'locale', 'Configuration changed: %{public}s', newConfig.language ?? '');
    // 系统资源会自行切换语言，修订号用于通知已挂载页面重新解析派生文案
    LocaleState.notifyChanged();
  }
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 页面创建前先注册全局状态，确保后续 @StorageLink 可以稳定订阅
    LocaleState.initialize();
    BreakpointUtil.initialize();
    VaultChangeNotifier.initialize();
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    DataPreferences.getInstance().init(this.context);
    try {
      void DatabaseUtil.init(this.context).then(() => {
        return DatabaseUtil.getInstance().createTable();
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to create database tables: %{public}s', err.message);
      });
      ShareDatabaseUtil.init(this.context);
      void this.initializeGeneratorDatabase();
    } catch (err) {
      console.error(`Failed to init database. Error: ${JSON.stringify(err)}`);
    }
  }

  private async initializeGeneratorDatabase(): Promise<void> {
    try {
      await GeneratorDatabaseUtil.init(this.context);
    } catch (err) {
      const error = err as Error;
      hilog.error(DOMAIN, 'testTag', 'Failed to initialize generator database: %{public}s', error.message);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    AppStorage.setOrCreate('windowStage', windowStage);
    void WindowPrivacyUtil.applyForCurrentState();
    void this.configurePcWindowLimits(windowStage);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      void SystemTrayManager.initialize(this.context, windowStage);
    });
  }

  private async configurePcWindowLimits(windowStage: window.WindowStage): Promise<void> {
    if (!FormFactorUtil.isPc()) {
      return;
    }

    try {
      const mainWindow = windowStage.getMainWindowSync();
      const appliedLimits = await mainWindow.setWindowLimits({
        minWidth: PC_MIN_WINDOW_WIDTH,
        minHeight: PC_MIN_WINDOW_HEIGHT,
        pixelUnit: window.PixelUnit.VP
      });
      hilog.info(DOMAIN, 'windowLimits', 'PC window limits applied: %{public}s', JSON.stringify(appliedLimits));
    } catch (error) {
      hilog.error(DOMAIN, 'windowLimits', 'Failed to apply PC window limits: %{public}s', JSON.stringify(error));
    }
  }

  onWindowStageDestroy(): void {
    SystemTrayManager.detachMainWindow();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

}
