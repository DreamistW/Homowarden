import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const MEDIUM_WIDTH = 600;
const LARGE_WIDTH = 840;

/** 应用内容区宽度对应的响应式断点。 */
export enum Breakpoint {
  SM = 'SM',
  MD = 'MD',
  LG = 'LG'
}

/** 根据应用内容区宽高推导出的布局方向。 */
export enum Orientation {
  PORTRAIT = 'PORTRAIT',
  LANDSCAPE = 'LANDSCAPE'
}

/** 维护自适应布局所需的断点、方向和分栏状态。 */
export class BreakpointUtil {
  private static lastState: string = '';

  static initialize(): void {
    // 必须先创建全局状态，页面的 @StorageLink 才能稳定订阅。
    AppStorage.setOrCreate<Breakpoint>('breakpoint', Breakpoint.SM);
    AppStorage.setOrCreate<Orientation>('orientation', Orientation.PORTRAIT);
    AppStorage.setOrCreate<boolean>('isSplitView', false);
  }

  static dispose(): void {
    BreakpointUtil.lastState = '';
  }

  static updateViewport(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }
    const breakpoint = width >= LARGE_WIDTH ? Breakpoint.LG :
      width >= MEDIUM_WIDTH ? Breakpoint.MD : Breakpoint.SM;
    // 部分折叠屏的媒体方向与实际布局不一致，以内容区宽高关系为准。
    const orientation = width > height ? Orientation.LANDSCAPE : Orientation.PORTRAIT;
    AppStorage.set<Breakpoint>('breakpoint', breakpoint);
    AppStorage.set<Orientation>('orientation', orientation);
    const isSplitView = breakpoint === Breakpoint.LG && orientation === Orientation.LANDSCAPE;
    AppStorage.set<boolean>('isSplitView', isSplitView);
    const state = `${width}x${height}/${breakpoint}/${orientation}/${isSplitView}`;
    if (state !== BreakpointUtil.lastState) {
      BreakpointUtil.lastState = state;
      hilog.warn(DOMAIN, 'testTag', 'Breakpoint state=%{public}s', state);
    }
  }
}
