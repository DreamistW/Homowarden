/** 主页面底部导航和宽屏侧栏共用的固定页签。 */
export enum MainTab {
  VAULT = 0,
  TOTP = 1,
  GENERATOR = 2,
  SHARE = 3,
  SETTINGS = 4
}

export interface MainNavigationItem {
  tab: MainTab;
  label: Resource;
  icon: Resource;
}

/** 集中创建导航资源，避免底栏和侧栏分别维护标签与图标。 */
export function mainNavigationItems(): MainNavigationItem[] {
  return [
    { tab: MainTab.VAULT, label: $r('app.string.nav_vault'), icon: $r('app.media.icon_home') },
    { tab: MainTab.TOTP, label: $r('app.string.nav_totp'), icon: $r('app.media.icon_key') },
    { tab: MainTab.GENERATOR, label: $r('app.string.nav_generator'), icon: $r('app.media.icon_password') },
    { tab: MainTab.SHARE, label: $r('app.string.nav_share'), icon: $r('app.media.icon_share') },
    { tab: MainTab.SETTINGS, label: $r('app.string.nav_settings'), icon: $r('app.media.icon_settings') }
  ];
}
