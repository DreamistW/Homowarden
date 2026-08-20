import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SystemTrayManager } from '../utils/SystemTrayManager';

const DOMAIN = 0x0000;
const TAG = 'TrayKeepAlive';

/**
 * Invisible PC-only ability whose process is attached to the status bar item.
 * It keeps the tray entry alive after the visible EntryAbility is closed.
 */
export default class TrayKeepAliveAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    SystemTrayManager.attachKeepAliveContext(this.context);
    hilog.info(DOMAIN, TAG, 'Hidden tray keep-alive ability created.');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    SystemTrayManager.attachKeepAliveContext(this.context);
    hilog.info(DOMAIN, TAG, 'Hidden tray keep-alive ability reused.');
  }

  onDestroy(): void {
    SystemTrayManager.detachKeepAliveContext();
    hilog.info(DOMAIN, TAG, 'Hidden tray keep-alive ability destroyed.');
  }
}
