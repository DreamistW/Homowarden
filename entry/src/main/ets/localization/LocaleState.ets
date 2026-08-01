/** 通过 AppStorage 修订号向已挂载组件广播系统语言变化。 */
export class LocaleState {
  static revision: number = 0;

  static initialize(): void {
    AppStorage.setOrCreate<number>('localeRevision', LocaleState.revision);
  }

  static notifyChanged(): void {
    // 递增值用于触发 @StorageLink/@Watch，即使新旧语言由系统资源管理器维护。
    LocaleState.revision += 1;
    AppStorage.set<number>('localeRevision', LocaleState.revision);
  }
}
