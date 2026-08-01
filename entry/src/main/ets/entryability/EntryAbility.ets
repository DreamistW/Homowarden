import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DataPreferences } from '@abner/datastore';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { ShareDatabaseUtil } from '../utils/ShareDatabaseUtil';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { LocaleState } from '../localization/LocaleState';

const DOMAIN = 0x0000;
export default class EntryAbility extends UIAbility {
  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, 'locale', 'Configuration changed: %{public}s', newConfig.language ?? '');
    LocaleState.notifyChanged();
  }
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    LocaleState.initialize();
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
    } catch (err) {
      console.error(`Failed to init database. Error: ${JSON.stringify(err)}`);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

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
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

}
