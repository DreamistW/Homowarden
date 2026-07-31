export class LocaleState {
  static revision: number = 0;

  static initialize(): void {
    AppStorage.setOrCreate<number>('localeRevision', LocaleState.revision);
  }

  static notifyChanged(): void {
    LocaleState.revision += 1;
    AppStorage.set<number>('localeRevision', LocaleState.revision);
  }
}
