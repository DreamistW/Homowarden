/**
 * 统一通过当前 UIContext 展示短时提示，避免依赖已废弃的全局提示接口。
 */
export class AppToast {
  static show(uiContext: UIContext, message: ResourceStr): void {
    uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
  }
}
