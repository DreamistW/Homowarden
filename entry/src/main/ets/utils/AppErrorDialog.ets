import { Logger } from '@nzy/logger';
import { ErrorMessageUtil } from './ErrorMessageUtil';

interface InlineErrorTarget {
  owner: Object;
  show: (message: ResourceStr) => void;
}

/** 错误只负责告知；确认按钮不重试、不导航。已有弹窗时在原弹窗内显示。 */
export class AppErrorDialog {
  private static inlineTargets: InlineErrorTarget[] = [];
  private static showing: boolean = false;
  private static currentMessage: string = '';
  private static pending: ResourceStr[] = [];

  static registerInline(owner: Object, show: (message: ResourceStr) => void): void {
    AppErrorDialog.unregisterInline(owner);
    AppErrorDialog.inlineTargets.push({ owner: owner, show: show });
  }

  static unregisterInline(owner: Object): void {
    AppErrorDialog.inlineTargets = AppErrorDialog.inlineTargets.filter((target: InlineErrorTarget) => target.owner !== owner);
  }

  static showError(uiContext: UIContext, error: Object | null | undefined, fallback: ResourceStr): void {
    AppErrorDialog.show(uiContext, ErrorMessageUtil.getDisplayMessage(uiContext, error, fallback));
  }

  /** 独立错误弹窗在详情之后补充日志求助入口，沿用当前界面语言。 */
  private static messageWithHelp(uiContext: UIContext, message: ResourceStr): ResourceStr {
    const manager = uiContext.getHostContext()?.resourceManager;
    if (!manager) {
      return message;
    }
    // Resource 对象重载可能沿用旧语言，按资源 ID 读取才能跟随应用内语言切换。
    const detail = typeof message === 'string' ? message : manager.getStringSync(message.id);
    return detail + '\n\n' + manager.getStringSync($r('app.string.error_dialog_help_hint').id);
  }

  static show(uiContext: UIContext, message: ResourceStr): void {
    const targets = AppErrorDialog.inlineTargets;
    if (targets.length > 0) {
      targets[targets.length - 1].show(message);
      return;
    }
    if (AppErrorDialog.showing) {
      if (JSON.stringify(message) !== AppErrorDialog.currentMessage &&
        !AppErrorDialog.pending.some((item: ResourceStr) => JSON.stringify(item) === JSON.stringify(message))) {
        AppErrorDialog.pending.push(message);
      }
      return;
    }
    AppErrorDialog.showing = true;
    AppErrorDialog.currentMessage = JSON.stringify(message);
    try {
      uiContext.getPromptAction().showDialog({
        title: $r('app.string.error_dialog_title'),
        message: AppErrorDialog.messageWithHelp(uiContext, message),
        buttons: [{ text: $r('app.string.common_got_it'), color: '#2777DA', primary: true }]
      }).catch(() => {
        Logger.error('Failed to display error dialog');
      }).finally(() => {
        AppErrorDialog.showing = false;
        AppErrorDialog.currentMessage = '';
        const next = AppErrorDialog.pending.shift();
        if (next !== undefined) {
          AppErrorDialog.show(uiContext, next);
        }
      });
    } catch (_) {
      AppErrorDialog.showing = false;
      AppErrorDialog.currentMessage = '';
      AppErrorDialog.pending = [];
      Logger.error('Failed to display error dialog');
    }
  }
}
