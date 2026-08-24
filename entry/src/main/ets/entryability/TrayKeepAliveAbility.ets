import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SystemTrayManager } from '../utils/SystemTrayManager';

const DOMAIN = 0x0000;
const TAG = 'TrayKeepAlive';

/**
 * 仅供 PC 使用的隐藏 Ability，其进程附着于状态栏项目
 * 在可见的 EntryAbility 关闭后继续维持托盘入口
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
