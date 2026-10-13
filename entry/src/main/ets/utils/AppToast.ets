import { ErrorMessageUtil } from './ErrorMessageUtil';

/**
 * 统一通过当前 UIContext 展示短时提示，避免依赖已废弃的全局提示接口
 */
export class AppToast {
  static show(uiContext: UIContext, message: ResourceStr, requestFailed: boolean = false): void {
    if (requestFailed) {
      const context = uiContext.getHostContext();
      if (context) {
        const detail = typeof message === 'string' ? message : context.resourceManager.getStringSync(message.id);
        uiContext.getPromptAction().showToast({
          message: $r('app.string.http_request_failed', detail),
          duration: 2000
        });
        return;
      }
    }
    uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
  }

  static showError(uiContext: UIContext, error: Object, fallback: ResourceStr): void {
    AppToast.show(uiContext, fallback, ErrorMessageUtil.isRequestFailure(error));
  }
}
