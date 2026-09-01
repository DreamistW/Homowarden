export interface HistorySelectionIndicatorOptions {
  selected: boolean;
}

export interface HistorySelectionBarOptions {
  allSelected: boolean;
  selectedCount: number;
  selectedCountText: string;
  onCancel: () => void;
  onToggleAll: () => void;
  onDelete: () => void;
}

@Builder
export function HistorySelectionIndicator(options: HistorySelectionIndicatorOptions) {
  Stack() {
    if (options.selected) {
      Text('✓')
        .fontSize(14)
        .fontColor($r('app.color.button_foreground_color'))
        .accessibilityLevel('no')
    }
  }
  .width(22)
  .height(22)
  .borderRadius(11)
  .backgroundColor(options.selected ? $r('app.color.button_background_color') : Color.Transparent)
  .border({ width: options.selected ? 0 : 1.5, color: '#CCCCCC' })
  .margin({ right: 12 })
  .accessibilityLevel('no')
}

@Builder
export function HistorySelectionBar(options: HistorySelectionBarOptions) {
  Row({ space: 12 }) {
    Button($r('app.string.common_cancel'))
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .fontColor($r('app.color.button_background_color'))
      .fontSize(16)
      .height(40)
      .onClick(() => {
        options.onCancel();
      })

    Button(options.allSelected ? $r('app.string.common_deselect_all') : $r('app.string.common_select_all'))
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .fontColor($r('app.color.button_background_color'))
      .fontSize(16)
      .height(40)
      .onClick(() => {
        options.onToggleAll();
      })

    Blank()

    Text(options.selectedCountText)
      .fontColor('#666666')
      .fontSize(14)

    Button() {
      Image($r('app.media.icon_delete'))
        .width(20)
        .height(20)
        .fillColor($r('app.color.button_foreground_color'))
        .accessibilityLevel('no')
    }
    .type(ButtonType.Circle)
    .width(40)
    .height(40)
    .padding(0)
    .backgroundColor($r('app.color.button_background_color'))
    .enabled(options.selectedCount > 0)
    .opacity(options.selectedCount > 0 ? 1 : 0.4)
    .accessibilityText($r('app.string.common_delete'))
    .onClick(() => {
      options.onDelete();
    })
  }
  .width('100%')
  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
  .backgroundColor($r('app.color.start_window_background'))
}
