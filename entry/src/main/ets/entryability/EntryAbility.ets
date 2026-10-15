import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
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
import { LogExportService } from '../utils/LogExportService';
import { CredentialStore } from '../utils/CredentialStore';
import { QuickEntryManager } from '../utils/QuickEntryManager';
import { AppearanceUtil } from '../utils/AppearanceUtil';

const DOMAIN = 0x0000;
const PC_MIN_WINDOW_WIDTH = 840;
const RESPONSIVE_MIN_VIEWPORT_SIZE = 600;
const PC_MIN_WINDOW_HEIGHT = RESPONSIVE_MIN_VIEWPORT_SIZE;
export default class EntryAbility extends UIAbility {
  private mainWindow?: window.Window;
  private preferredOrientation?: window.Orientation;
  private readonly onMainWindowSizeChange = (size: window.Size): void => {
    void this.updateResponsiveOrientation(size.width, size.height);
  };

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, 'locale', 'Configuration changed: %{public}s', newConfig.language ?? '');
    // 系统资源会自行切换语言，修订号用于通知已挂载页面重新解析派生文案
    LocaleState.notifyChanged();
  }
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    QuickEntryManager.handleWant(want);
    LogExportService.initialize(this.context);
    // 页面创建前先注册全局状态，确保后续 @StorageLink 可以稳定订阅
    LocaleState.initialize();
    try {
      AppearanceUtil.initialize(this.context);
      AppearanceUtil.startLanguageObserver();
    } catch (error) {
      hilog.error(DOMAIN, 'appearance', 'Failed to initialize appearance preferences: %{public}s', JSON.stringify(error));
    }
    BreakpointUtil.initialize();
    VaultChangeNotifier.initialize();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    DataPreferences.getInstance().init(this.context);
    void CredentialStore.initialize(this.context).catch(() => {
      hilog.error(DOMAIN, 'credentials', 'Credential storage initialization failed; waiting for retry');
    });
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

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    QuickEntryManager.handleWant(want);
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
    AppearanceUtil.stopLanguageObserver();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    AppStorage.setOrCreate('windowStage', windowStage);
    void WindowPrivacyUtil.applyForCurrentState();
    this.configureResponsiveOrientation(windowStage);
    void this.configurePcWindowLimits(windowStage);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      AppearanceUtil.restoreColor(this.context);
      void SystemTrayManager.initialize(this.context, windowStage);
    });
  }

  private configureResponsiveOrientation(windowStage: window.WindowStage): void {
    if (!FormFactorUtil.supportsResponsiveOrientation()) {
      return;
    }

    try {
      this.mainWindow = windowStage.getMainWindowSync();
      this.mainWindow.on('windowSizeChange', this.onMainWindowSizeChange);
      const windowRect = this.mainWindow.getWindowProperties().windowRect;
      void this.updateResponsiveOrientation(windowRect.width, windowRect.height);
    } catch (error) {
      hilog.error(DOMAIN, 'orientation', 'Failed to configure responsive orientation: %{public}s', JSON.stringify(error));
    }
  }

  private async updateResponsiveOrientation(widthPx: number, heightPx: number): Promise<void> {
    if (!this.mainWindow || widthPx <= 0 || heightPx <= 0) {
      return;
    }

    try {
      const density = display.getDefaultDisplaySync().densityPixels;
      const shortestSideVp = Math.round(Math.min(widthPx, heightPx) / density);
      const orientation = shortestSideVp >= RESPONSIVE_MIN_VIEWPORT_SIZE ?
        window.Orientation.AUTO_ROTATION : window.Orientation.PORTRAIT;
      if (orientation === this.preferredOrientation) {
        return;
      }

      this.preferredOrientation = orientation;
      await this.mainWindow.setPreferredOrientation(orientation);
      hilog.info(DOMAIN, 'orientation', 'Responsive orientation=%{public}d, shortestSideVp=%{public}d',
        orientation, shortestSideVp);
    } catch (error) {
      this.preferredOrientation = undefined;
      hilog.error(DOMAIN, 'orientation', 'Failed to update responsive orientation: %{public}s', JSON.stringify(error));
    }
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

  onWindowStageWillDestroy(): void {
    // 窗口仍可用，必须在这里解绑；onWindowStageDestroy 时 Window 已是 nullptr
    this.unregisterMainWindowSizeChange();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageWillDestroy');
  }

  onWindowStageDestroy(): void {
    this.mainWindow = undefined;
    this.preferredOrientation = undefined;
    SystemTrayManager.detachMainWindow();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  private unregisterMainWindowSizeChange(): void {
    const currentWindow = this.mainWindow;
    if (!currentWindow) {
      return;
    }

    try {
      currentWindow.off('windowSizeChange', this.onMainWindowSizeChange);
    } catch (error) {
      hilog.error(DOMAIN, 'orientation',
        'Failed to unregister windowSizeChange: %{public}s', JSON.stringify(error));
    }
    this.mainWindow = undefined;
  }

  onForeground(): void {
    AppearanceUtil.syncSystemLanguage();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

}
