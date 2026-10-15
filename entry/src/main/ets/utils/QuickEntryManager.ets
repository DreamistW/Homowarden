import { shortcutManager, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MainTab } from '../component/MainNavigationItems';
import { FormFactorUtil } from './FormFactorUtil';

export const QUICK_ENTRY_PARAMETER = 'homowarden.quickEntry';

export interface QuickEntryItem {
  id: string;
  tab: MainTab;
  label: string;
}

/** 桌面长按菜单与托盘共用的入口；待处理目标只保存在内存中，解锁后再消费。 */
export class QuickEntryManager {
  static readonly items: QuickEntryItem[] = [
    { id: 'totp', tab: MainTab.TOTP, label: 'nav_totp' },
    { id: 'generator', tab: MainTab.GENERATOR, label: 'nav_generator' },
    { id: 'share', tab: MainTab.SHARE, label: 'nav_share' }
  ];
  private static loggedIn: boolean = false;
  private static loginStateKnown: boolean = false;
  private static pending: MainTab | null = null;
  private static navigationHandler: (() => void) | null = null;
  private static loginStateHandler: (() => Promise<void>) | null = null;
  private static visibilityUpdate: Promise<void> = Promise.resolve();

  static isLoggedIn(): boolean {
    return QuickEntryManager.loggedIn;
  }

  static async updateLoginState(loggedIn: boolean): Promise<void> {
    QuickEntryManager.loggedIn = loggedIn;
    QuickEntryManager.loginStateKnown = true;
    if (!loggedIn) {
      QuickEntryManager.pending = null;
    }
    // 串行更新系统状态，防止登录、注销交错时旧的注册覆盖注销结果。
    QuickEntryManager.visibilityUpdate = QuickEntryManager.visibilityUpdate.then(async () => {
      if (!FormFactorUtil.isPc() && canIUse('SystemCapability.BundleManager.BundleFramework.Launcher')) {
        await Promise.all(QuickEntryManager.items.map(async (item: QuickEntryItem) => {
          try {
            await shortcutManager.setShortcutVisibleForSelf(item.id, loggedIn);
          } catch (error) {
            hilog.error(0x0000, 'QuickEntry', 'Failed to update shortcut %{public}s: %{public}s',
              item.id, JSON.stringify(error));
          }
        }));
      }
      await QuickEntryManager.loginStateHandler?.();
    }).catch((error: Error) => {
      hilog.error(0x0000, 'QuickEntry', 'Failed to synchronize menus: %{public}s', JSON.stringify(error));
    });
    await QuickEntryManager.visibilityUpdate;
  }

  static registerLoginStateHandler(handler: () => Promise<void>): void {
    QuickEntryManager.loginStateHandler = handler;
  }

  static handleWant(want: Want): void {
    QuickEntryManager.request(want.parameters?.[QUICK_ENTRY_PARAMETER]);
  }

  static request(value: Object | undefined): void {
    if (QuickEntryManager.loginStateKnown && !QuickEntryManager.loggedIn) {
      return;
    }
    const item = QuickEntryManager.items.find((entry: QuickEntryItem) => entry.id === value);
    if (!item) {
      return;
    }
    QuickEntryManager.pending = item.tab;
    QuickEntryManager.dispatchPending();
  }

  static registerNavigationHandler(handler: () => void): void {
    QuickEntryManager.navigationHandler = handler;
  }

  static unregisterNavigationHandler(handler: () => void): void {
    if (QuickEntryManager.navigationHandler === handler) {
      QuickEntryManager.navigationHandler = null;
    }
  }

  static dispatchPending(): void {
    if (QuickEntryManager.loggedIn && QuickEntryManager.pending !== null) {
      QuickEntryManager.navigationHandler?.();
    }
  }

  static consumePending(): MainTab | null {
    const tab = QuickEntryManager.pending;
    QuickEntryManager.pending = null;
    return QuickEntryManager.loggedIn ? tab : null;
  }

  static clearPending(): void {
    QuickEntryManager.pending = null;
  }
}
