import { common } from '@kit.AbilityKit';
import { emitter } from '@kit.BasicServicesKit';
import { statusBarManager } from '@kit.DeskTopExtensionKit';
import { image } from '@kit.ImageKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'SystemTray';
const OPEN_MENU_CODE = 'open';

/**
 * Manages the PC/2in1 status bar icon and close-to-tray behavior.
 * Desktop Extension Kit APIs are guarded by a capability check so this class
 * can remain in the shared phone/tablet/2in1 HAP.
 */
export class SystemTrayManager {
  private static isRegistered: boolean = false;
  private static mainWindow: window.Window | null = null;

  private static readonly iconClickCallback = (eventData: emitter.EventData): void => {
    const data = eventData.data;
    if (data && data['iconClickType'] === 'leftClick') {
      void SystemTrayManager.restoreMainWindow();
    }
  };

  private static readonly rightMenuClickCallback = (eventData: emitter.EventData): void => {
    const data = eventData.data;
    if (data && data['menuCode'] === OPEN_MENU_CODE) {
      void SystemTrayManager.restoreMainWindow();
    }
  };

  private static readonly windowWillCloseCallback = async (): Promise<boolean> => {
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

      SystemTrayManager.mainWindow = windowStage.getMainWindowSync();
      if (!SystemTrayManager.isRegistered) {
        await SystemTrayManager.addStatusBarIcon(context);
        statusBarManager.on('statusBarIconClick', SystemTrayManager.iconClickCallback);
        statusBarManager.on('rightMenuClick', SystemTrayManager.rightMenuClickCallback);
        SystemTrayManager.isRegistered = true;
      }

      SystemTrayManager.mainWindow.on('windowWillClose', SystemTrayManager.windowWillCloseCallback);
      hilog.info(DOMAIN, TAG, 'Status bar icon and close-to-tray behavior are ready.');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize system tray: %{public}s', JSON.stringify(error));
    }
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
      abilityName: 'EntryAbility',
      moduleName: 'entry',
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
        moduleName: 'entry'
      },
      statusBarGroupMenu: [[openMenuItem]],
      hoverTips: appName
    };

    statusBarManager.addToStatusBar(context, item);
    hilog.info(DOMAIN, TAG, 'Status bar icon added.');
  }

  private static async restoreMainWindow(): Promise<void> {
    const currentWindow = SystemTrayManager.mainWindow;
    if (!currentWindow) {
      hilog.warn(DOMAIN, TAG, 'Cannot restore main window because it is unavailable.');
      return;
    }

    try {
      await currentWindow.restore();
      hilog.info(DOMAIN, TAG, 'Main window restored from the status bar.');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to restore main window: %{public}s', JSON.stringify(error));
    }
  }
}
