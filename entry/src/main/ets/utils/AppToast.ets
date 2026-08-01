export class AppToast {
  static show(uiContext: UIContext, message: ResourceStr): void {
    uiContext.getPromptAction().showToast({ message: message, duration: 2000 });
  }
}
