import { EntryRouter } from '../../../../EntryRouter';

/** 统一单栏压栈与分栏右侧替换的详情路由语义。 */
export class DetailRouter {
  private static detailStack: NavPathStack | null = null;

  static registerDetailStack(stack: NavPathStack): void {
    DetailRouter.detailStack = stack;
  }

  static openDetail(primaryStack: NavPathStack, detailStack: NavPathStack, isSplit: boolean,
    name: string, param?: Object): void {
    const path: NavPathInfo = { name: name, param: param };
    if (isSplit) {
      detailStack.replacePath(path);
      return;
    }
    primaryStack.pushPath(path);
  }

  static openHistory(primaryStack: NavPathStack, detailStack: NavPathStack, isSplit: boolean,
    name: string): void {
    DetailRouter.openDetail(primaryStack, detailStack, isSplit, name);
  }

  static closeDetail(stack: NavPathStack): void {
    // 页面可能在异步操作期间发生旋转，必须按实际所属栈决定关闭方式。
    if (stack === DetailRouter.detailStack) {
      stack.replacePath({ name: EntryRouter.DetailPlaceholder });
      return;
    }
    stack.pop();
  }
}
