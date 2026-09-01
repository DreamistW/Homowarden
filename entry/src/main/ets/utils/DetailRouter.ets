import { EntryRouter } from '../../../../EntryRouter';

/** 统一单栏压栈与分栏右侧替换的详情路由语义 */
export class DetailRouter {
  private static closeHandler: (() => void) | null = null;

  static registerCloseHandler(handler: () => void): void {
    DetailRouter.closeHandler = handler;
  }

  static unregisterCloseHandler(handler: () => void): void {
    if (DetailRouter.closeHandler === handler) {
      DetailRouter.closeHandler = null;
    }
  }

  static showPlaceholder(stack: NavPathStack): void {
    const placeholder: NavPathInfo = { name: EntryRouter.DetailPlaceholder };
    const pathNames = stack.getAllPathName();
    if (!pathNames || pathNames.length === 0) {
      stack.pushPath(placeholder);
      return;
    }
    stack.replacePath(placeholder);
  }

  static openDetail(primaryStack: NavPathStack, detailStack: NavPathStack, isSplit: boolean,
    name: string, param?: Object): void {
    const path: NavPathInfo = { name: name, param: param };
    if (isSplit) {
      const pathNames = detailStack.getAllPathName();
      if (!pathNames || pathNames.length === 0) {
        detailStack.pushPath(path);
      } else {
        detailStack.replacePath(path);
      }
      return;
    }
    primaryStack.pushPath(path);
  }

  static openHistory(primaryStack: NavPathStack, detailStack: NavPathStack, isSplit: boolean,
    name: string): void {
    DetailRouter.openDetail(primaryStack, detailStack, isSplit, name);
  }

  static closeDetail(): void {
    DetailRouter.closeHandler?.();
  }
}
