import { common, contextConstant, StartOptions, Want } from '@kit.AbilityKit';
import { BusinessError, emitter } from '@kit.BasicServicesKit';
import { statusBarManager } from '@kit.DeskTopExtensionKit';
import { image } from '@kit.ImageKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'SystemTray';
const OPEN_MENU_CODE = 'open';
const ENTRY_ABILITY_NAME = 'EntryAbility';
const KEEP_ALIVE_ABILITY_NAME = 'TrayKeepAliveAbility';
const ENTRY_MODULE_NAME = 'entry';
const START_OPTIONS_CHECK_FAILED = 16000067;
const KEEP_ALIVE_START_MAX_ATTEMPTS = 3;
const KEEP_ALIVE_START_RETRY_DELAY_MS = 100;

/**
 * Manages the PC/2in1 status bar icon and close-to-tray behavior.
 * Desktop Extension Kit APIs are guarded by a capability check so this class
 * can remain in the shared phone/tablet/2in1 HAP.
 */
export class SystemTrayManager {
  private static isRegistered: boolean = false;
  private static isKeepAliveReady: boolean = false;
  private static mainWindow: window.Window | null = null;
  private static fallbackContext: common.UIAbilityContext | null = null;
  private static keepAliveContext: common.UIAbilityContext | null = null;

  private static readonly iconClickCallback = (eventData: emitter.EventData): void => {
    const data = eventData.data;
    if (data && data['iconClickType'] === 'leftClick') {
      void SystemTrayManager.openMainWindow();
    }
  };

  private static readonly rightMenuClickCallback = (eventData: emitter.EventData): void => {
    const data = eventData.data;
    if (data && data['menuCode'] === OPEN_MENU_CODE) {
      void SystemTrayManager.openMainWindow();
    }
  };

  private static readonly windowWillCloseCallback = async (): Promise<boolean> => {
    if (SystemTrayManager.isKeepAliveReady) {
      hilog.info(DOMAIN, TAG, 'Main window will close while the status bar process remains active.');
      return false;
    }

    const currentWindow = SystemTrayManager.mainWindow;
    if (!currentWindow) {
      return false;
    }

    try {
      await currentWindow.minimize();
      hilog.info(DOMAIN, TAG, 'Main window minimized from the close button.');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to minimize main window: %{public}s', JSON.stringify(error));
      return false;
    }
  };

  static async initialize(context: common.UIAbilityContext, windowStage: window.WindowStage): Promise<void> {
    try {
      const isSupported = await statusBarManager.isStatusBarCapabilitySupported(context);
      if (!isSupported) {
        hilog.info(DOMAIN, TAG, 'Status bar capability is not supported on this device.');
        return;
      }

      SystemTrayManager.fallbackContext = context;
      SystemTrayManager.mainWindow = windowStage.getMainWindowSync();
      if (!SystemTrayManager.isRegistered) {
        await SystemTrayManager.addStatusBarIcon(context);
        statusBarManager.on('statusBarIconClick', SystemTrayManager.iconClickCallback);
        statusBarManager.on('rightMenuClick', SystemTrayManager.rightMenuClickCallback);
        SystemTrayManager.isRegistered = true;
      }

      await SystemTrayManager.startKeepAliveAbility(context);
      SystemTrayManager.mainWindow.on('windowWillClose', SystemTrayManager.windowWillCloseCallback);
      hilog.info(DOMAIN, TAG, 'Status bar icon and close-to-tray behavior are ready. Keep-alive: %{public}s',
        SystemTrayManager.isKeepAliveReady ? 'enabled' : 'fallback-to-minimize');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize system tray: %{public}s', JSON.stringify(error));
    }
  }

  static attachKeepAliveContext(context: common.UIAbilityContext): void {
    SystemTrayManager.keepAliveContext = context;
    SystemTrayManager.isKeepAliveReady = true;
    hilog.info(DOMAIN, TAG, 'Hidden keep-alive ability attached to the status bar item.');
  }

  static detachKeepAliveContext(): void {
    SystemTrayManager.keepAliveContext = null;
    SystemTrayManager.isKeepAliveReady = false;
    hilog.info(DOMAIN, TAG, 'Hidden keep-alive ability detached from the status bar item.');
  }

  static detachMainWindow(): void {
    SystemTrayManager.mainWindow = null;
    SystemTrayManager.fallbackContext = null;
  }

  private static async startKeepAliveAbility(context: common.UIAbilityContext): Promise<void> {
    if (SystemTrayManager.isKeepAliveReady) {
      return;
    }

    const want: Want = {
      bundleName: context.applicationInfo.name,
      moduleName: ENTRY_MODULE_NAME,
      abilityName: KEEP_ALIVE_ABILITY_NAME
    };
    const options: StartOptions = {
      // Keep the event listeners and hidden ability in the same process, then
      // bind that process to the status bar item so icon clicks remain routed.
      processMode: contextConstant.ProcessMode.ATTACH_TO_STATUS_BAR_ITEM,
      startupVisibility: contextConstant.StartupVisibility.STARTUP_HIDE
    };
    for (let attempt = 1; attempt <= KEEP_ALIVE_START_MAX_ATTEMPTS; attempt++) {
      try {
        await context.startAbility(want, options);
        SystemTrayManager.isKeepAliveReady = true;
        hilog.info(DOMAIN, TAG, 'Hidden keep-alive ability started on attempt %{public}d.', attempt);
        return;
      } catch (error) {
        const businessError = error as BusinessError;
        const shouldRetry = businessError.code === START_OPTIONS_CHECK_FAILED &&
          attempt < KEEP_ALIVE_START_MAX_ATTEMPTS;
        if (!shouldRetry) {
          SystemTrayManager.isKeepAliveReady = false;
          hilog.error(DOMAIN, TAG, 'Failed to start hidden keep-alive ability: %{public}s', JSON.stringify(error));
          return;
        }

        hilog.warn(DOMAIN, TAG,
          'Status bar item is not ready yet; retrying hidden keep-alive ability startup after %{public}d ms.',
          KEEP_ALIVE_START_RETRY_DELAY_MS);
        await SystemTrayManager.delay(KEEP_ALIVE_START_RETRY_DELAY_MS);
      }
    }
  }

  private static delay(delayMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, delayMs);
    });
  }

  private static async addStatusBarIcon(context: common.UIAbilityContext): Promise<void> {
    const resourceManager = context.resourceManager;
    const whiteFileData = resourceManager.getRawFileContentSync('tray_white.svg');
    const blackFileData = resourceManager.getRawFileContentSync('tray_black.svg');
    const whiteImageSource = image.createImageSource(whiteFileData.buffer);
    const blackImageSource = image.createImageSource(blackFileData.buffer);
    let whitePixelMap: image.PixelMap;
    let blackPixelMap: image.PixelMap;
    try {
      whitePixelMap = await whiteImageSource.createPixelMap();
      blackPixelMap = await blackImageSource.createPixelMap();
    } finally {
      await Promise.all([whiteImageSource.release(), blackImageSource.release()]);
    }
    const appName = resourceManager.getStringByNameSync('EntryAbility_label');
    const openLabel = resourceManager.getStringByNameSync('tray_open');

    const openAction: statusBarManager.StatusBarMenuAction = {
      abilityName: ENTRY_ABILITY_NAME,
      moduleName: ENTRY_MODULE_NAME,
      notifyOnly: true
    };
    const openMenuItem: statusBarManager.StatusBarMenuItem = {
      title: openLabel,
      menuCode: OPEN_MENU_CODE,
      menuAction: openAction
    };
    const item: statusBarManager.StatusBarItem = {
      icons: {
        white: whitePixelMap,
        black: blackPixelMap
      },
      quickOperation: {
        abilityName: '',
        title: appName,
        height: 1,
        moduleName: ENTRY_MODULE_NAME
      },
      statusBarGroupMenu: [[openMenuItem]],
      hoverTips: appName
    };

    statusBarManager.addToStatusBar(context, item);
    hilog.info(DOMAIN, TAG, 'Status bar icon added.');
  }

  private static async openMainWindow(): Promise<void> {
    try {
      if (!SystemTrayManager.isKeepAliveReady && SystemTrayManager.mainWindow) {
        await SystemTrayManager.mainWindow.restore();
        hilog.info(DOMAIN, TAG, 'Main window restored from the status bar fallback.');
        return;
      }

      const context = SystemTrayManager.keepAliveContext ?? SystemTrayManager.fallbackContext;
      if (!context) {
        hilog.warn(DOMAIN, TAG, 'Cannot open main window because no ability context is available.');
        return;
      }
      const want: Want = {
        bundleName: context.applicationInfo.name,
        moduleName: ENTRY_MODULE_NAME,
        abilityName: ENTRY_ABILITY_NAME
      };
      await context.startAbility(want);
      hilog.info(DOMAIN, TAG, 'Main window opened from the status bar.');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to open main window: %{public}s', JSON.stringify(error));
    }
  }
}
