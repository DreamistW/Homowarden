export type DetailLeaveHandler = (onLeave: () => void, onStay: () => void) => void;

/** 让侧栏切换复用当前详情页的未保存改动确认逻辑。 */
export class DetailLeaveGuard {
  private static handler: DetailLeaveHandler | null = null;
  private static isRequesting: boolean = false;

  static register(handler: DetailLeaveHandler): void {
    DetailLeaveGuard.handler = handler;
  }

  static unregister(handler: DetailLeaveHandler): void {
    if (DetailLeaveGuard.handler === handler) {
      DetailLeaveGuard.handler = null;
    }
  }

  static requestLeave(onLeave: () => void): void {
    if (DetailLeaveGuard.isRequesting) {
      return;
    }
    const handler = DetailLeaveGuard.handler;
    if (handler) {
      DetailLeaveGuard.isRequesting = true;
      handler(() => {
        DetailLeaveGuard.isRequesting = false;
        onLeave();
      }, () => {
        DetailLeaveGuard.isRequesting = false;
      });
      return;
    }
    onLeave();
  }
}
