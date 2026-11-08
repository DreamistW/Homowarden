import { ErrorMessageUtil } from './ErrorMessageUtil';

interface BackgroundIssue {
  message: ResourceStr;
  error?: Object | null;
}

/** 后台错误按来源保存；查看不清除，只有对应操作恢复成功或会话结束才清除。 */
export class BackgroundErrorStore {
  private static messages: Map<string, BackgroundIssue> = new Map();

  static set(source: string, message: ResourceStr): void {
    BackgroundErrorStore.setError(source, null, message);
  }

  static setError(source: string, error: Object | null | undefined, message: ResourceStr): void {
    const issue: BackgroundIssue = { message: message, error: error };
    const previous = BackgroundErrorStore.messages.get(source);
    if (previous && JSON.stringify(previous.message) === JSON.stringify(message) &&
      previous.error === error) {
      return;
    }
    BackgroundErrorStore.messages.set(source, issue);
    BackgroundErrorStore.notify();
  }

  static clear(source: string): void {
    if (BackgroundErrorStore.messages.delete(source)) {
      BackgroundErrorStore.notify();
    }
  }

  static clearAll(): void {
    if (BackgroundErrorStore.messages.size > 0) {
      BackgroundErrorStore.messages.clear();
      BackgroundErrorStore.notify();
    }
  }

  static hasErrors(source: string = ''): boolean {
    return source ? BackgroundErrorStore.messages.has(source) : BackgroundErrorStore.messages.size > 0;
  }

  static message(uiContext?: UIContext, source: string = ''): string {
    const selected = source ? [BackgroundErrorStore.messages.get(source)].filter((issue: BackgroundIssue | undefined) =>
      issue !== undefined) as BackgroundIssue[] : Array.from(BackgroundErrorStore.messages.values());
    return selected.map((issue: BackgroundIssue): string => {
      const message = issue.message;
      if (uiContext && issue.error) {
        return ErrorMessageUtil.getDisplayMessage(uiContext, issue.error, message);
      }
      if (typeof message === 'string') {
        return message;
      }
      return uiContext?.getHostContext()?.resourceManager.getStringSync(message.id) ?? '';
    }).filter((message: string) => message.length > 0).join('\n\n');
  }

  private static notify(): void {
    AppStorage.setOrCreate('backgroundErrorRevision', (AppStorage.get<number>('backgroundErrorRevision') ?? 0) + 1);
  }
}
