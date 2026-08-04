import { BusinessError, pasteboard } from '@kit.BasicServicesKit';

const BUTTON_CONTENT_PADDING = 8;

function getButtonContainerSize(buttonSize: number, contentPadding: number = BUTTON_CONTENT_PADDING): number {
  return buttonSize + contentPadding * 2;
}

function getButtonContainerHeight(buttonHeight: number, contentPadding: number = BUTTON_CONTENT_PADDING,
  barBottomMargin: number = 0): number {
  return getButtonContainerSize(buttonHeight, contentPadding) + barBottomMargin;
}

/** 使用应用主题色的自适应文本按钮。 */
@Component
export struct AdaptiveTextButton {
  text: ResourceStr = '';
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 18;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = BUTTON_CONTENT_PADDING;
  onButtonClick?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Button(this.text)
        .type(ButtonType.Capsule)
        .backgroundColor($r('app.color.button_background_color'))
        .fontColor($r('app.color.button_foreground_color'))
        .fontSize(this.fontSize)
        .borderColor(Color.Transparent)
        .borderWidth(0)
        .borderRadius(this.barHeight / 2)
        .padding(0)
        .width(this.barWidth)
        .height(this.barHeight)
        .onClick(() => {
          this.onButtonClick?.();
        })
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}

/** 使用应用主题色并提供无障碍标签的圆形图标按钮。 */
@Component
export struct AdaptiveIconButton {
  icon: Resource = $r('app.media.icon_add');
  accessibilityLabel: Resource = $r('app.string.common_unknown');
  barWidth: number = 50;
  barHeight: number = 50;
  iconWidth: number = 20;
  iconHeight: number = 20;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = BUTTON_CONTENT_PADDING;
  onButtonClick?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Button() {
        Image(this.icon)
          .width(this.iconWidth)
          .height(this.iconHeight)
          .fillColor($r('app.color.button_foreground_color'))
          .align(Alignment.Center)
          .accessibilityLevel('no')
      }
      .type(ButtonType.Circle)
      .backgroundColor($r('app.color.button_background_color'))
      .borderColor(Color.Transparent)
      .borderWidth(0)
      .borderRadius(this.barHeight / 2)
      .padding(0)
      .width(this.barWidth)
      .height(this.barHeight)
      .accessibilityText(this.accessibilityLabel)
      .onClick(() => {
        this.onButtonClick?.();
      })
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}

/** 绑定菜单选项的自适应文本按钮。 */
@Component
export struct AdaptiveMenuTextButton {
  text: ResourceStr = '';
  menuItems: MenuElement[] = [];
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 16;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = 0;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Button(this.text)
        .type(ButtonType.Capsule)
        .bindMenu(this.menuItems)
        .backgroundColor($r('app.color.button_background_color'))
        .fontColor($r('app.color.button_foreground_color'))
        .fontSize(this.fontSize)
        .borderColor(Color.Transparent)
        .borderWidth(0)
        .borderRadius(this.barHeight / 2)
        .padding(0)
        .width(this.barWidth)
        .height(this.barHeight)
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}

/** 通过系统安全控件读取剪贴板内容的自适应粘贴按钮。 */
@Component
export struct AdaptivePasteButton {
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 16;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = 0;
  onPaste?: (text: string) => void;
  onPasteError?: (err: BusinessError) => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      PasteButton({
        text: PasteDescription.PASTE,
        buttonType: ButtonType.Capsule
      })
        .backgroundColor($r('app.color.button_background_color'))
        .fontColor($r('app.color.button_foreground_color'))
        .fontSize(this.fontSize)
        .borderColor(Color.Transparent)
        .borderWidth(0)
        .borderRadius(this.barHeight / 2)
        .padding(0)
        .width(this.barWidth)
        .height(this.barHeight)
        .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
          // 仅在系统安全控件授权成功后读取剪贴板。
          if (PasteButtonOnClickResult.SUCCESS === result) {
            pasteboard.getSystemPasteboard()
              .getData((err: BusinessError, pasteData: pasteboard.PasteData) => {
                if (err) {
                  this.onPasteError?.(err);
                  return;
                }
                this.onPaste?.(pasteData.getPrimaryText());
              })
          }
        })
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}
