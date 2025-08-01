import { VaultPage } from './src/main/ets/pages/VaultPage';
import { SettingsPage } from './src/main/ets/pages/SettingsPage';
import { CipherDetailPage } from './src/main/ets/pages/CipherDetailPage';
import { AddCipherPage } from './src/main/ets/pages/AddCipherPage';
import { EntryRouter } from './EntryRouter';
import { LoginPage } from './src/main/ets/pages/LoginPage';
import { RouterConfig,routerGetBuilderType, routerInitBuilder,NavDestinationView } from '@abner/router';

/**
 * AUTHOR:AbnerMing
 * INTRODUCE:动态配置路径
 * */
function importPath(builderName: string) {
  switch (builderName) {
    case EntryRouter.VaultPage:
      import("./src/main/ets/pages/VaultPage")
      break
    case EntryRouter.SettingsPage:
      import("./src/main/ets/pages/SettingsPage")
      break
    case EntryRouter.LoginPage:
      import("./src/main/ets/pages/LoginPage")
      break
    case EntryRouter.CipherDetailPage:
      import("./src/main/ets/pages/CipherDetailPage")
      break
    case EntryRouter.AddCipherPage:
      import("./src/main/ets/pages/AddCipherPage")
      break
    case "login_page":
      import("./src/main/ets/pages/LoginPage")
      break

  }
}

/**
 * AUTHOR:AbnerMing
 * INTRODUCE:动态配置组件
 * */
@Builder
export function viewBuilder() {
  NavDestinationView() {
    if (routerGetBuilderType() == EntryRouter.VaultPage) {
      VaultPage()
    } else 
    if (routerGetBuilderType() == EntryRouter.SettingsPage) {
      SettingsPage()
    } else 
    if (routerGetBuilderType() == EntryRouter.LoginPage) {
      LoginPage()
    } else 
    if (routerGetBuilderType() == EntryRouter.CipherDetailPage) {
      CipherDetailPage()
    } else 
    if (routerGetBuilderType() == EntryRouter.AddCipherPage) {
      AddCipherPage()
    } else 
    if (routerGetBuilderType() == "login_page") {
      LoginPage()
    } 

  }

}


/**
 * AUTHOR:AbnerMing
 * DATE:2025年8月1日 10时56分0秒
 * INTRODUCE:路由配置,此路由配置文件为自动生成，无特殊情况下请无须改动
 * */
export class EntryRouterConfig implements RouterConfig {
  getModuleName(): string {
    return "entry"
  }

  async initRouter(builderName: string): Promise<void> {
    return await new Promise((resolve: Function) => {
      importPath(builderName)
      routerInitBuilder(builderName, wrapBuilder(viewBuilder))
      resolve()
    })
  }
}