import { BusinessError, pasteboard } from '@kit.BasicServicesKit';

const BUTTON_CONTENT_PADDING = 8;

function getButtonContainerSize(buttonSize: number, contentPadding: number = BUTTON_CONTENT_PADDING): number {
  return buttonSize + contentPadding * 2;
}

function getButtonContainerHeight(buttonHeight: number, contentPadding: number = BUTTON_CONTENT_PADDING,
  barBottomMargin: number = 0): number {
  return getButtonContainerSize(buttonHeight, contentPadding) + barBottomMargin;
}

/** 使用应用主题色的自适应文本按钮 */
@Component
export struct AdaptiveTextButton {
  @Prop text: ResourceStr = '';
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 18;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = BUTTON_CONTENT_PADDING;
  translucent: boolean = false;
  translucentFontColor: ResourceColor = $r('app.color.secondary_button_foreground_color');
  @Prop buttonEnabled: boolean = true;
  onButtonClick?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Button(this.text)
        .type(ButtonType.Capsule)
        .backgroundColor(this.translucent ? $r('app.color.secondary_button_background_color') :
          $r('app.color.button_background_color'))
        .fontColor(this.translucent ? this.translucentFontColor : $r('app.color.button_foreground_color'))
        .fontSize(this.fontSize)
        .borderColor(Color.Transparent)
        .borderWidth(0)
        .borderRadius(this.barHeight / 2)
        .padding(0)
        .width(this.barWidth)
        .height(this.barHeight)
        .enabled(this.buttonEnabled)
        .onClick(() => {
          this.onButtonClick?.();
        })
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}

/** 使用应用主题色并提供无障碍标签的圆形图标按钮 */
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
  translucent: boolean = false;
  buttonBackgroundColor: ResourceColor = $r('app.color.button_background_color');
  onButtonClick?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Button() {
        Image(this.icon)
          .width(this.iconWidth)
          .height(this.iconHeight)
          .fillColor(this.translucent ? $r('sys.color.icon_primary') : $r('app.color.button_foreground_color'))
          .align(Alignment.Center)
          .accessibilityLevel('no')
      }
      .type(ButtonType.Circle)
      .backgroundColor(this.translucent ? $r('app.color.translucent_button_background') :
        this.buttonBackgroundColor)
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

/** 绑定菜单选项的自适应文本按钮 */
@Component
export struct AdaptiveMenuTextButton {
  text: ResourceStr = '';
  menuItems: MenuElement[] = [];
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 16;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = 0;
  translucent: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Button(this.text)
        .type(ButtonType.Capsule)
        .bindMenu(this.menuItems, {
          backgroundColor: $r('app.color.menu_background_color'),
          backgroundBlurStyle: BlurStyle.NONE
        })
        .backgroundColor(this.translucent ? $r('app.color.translucent_button_background') :
          $r('app.color.button_background_color'))
        .fontColor(this.translucent ? $r('sys.color.font_primary') : $r('app.color.button_foreground_color'))
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

/** 通过系统安全控件读取剪贴板内容的自适应粘贴按钮 */
@Component
export struct AdaptivePasteButton {
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 16;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = 0;
  translucent: boolean = false;
  onPaste?: (text: string) => void;
  onPasteError?: (err: BusinessError) => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        PasteButton({
          text: PasteDescription.PASTE,
          buttonType: ButtonType.Capsule
        })
          .backgroundColor(this.translucent ? $r('app.color.secure_translucent_button_background') :
            $r('app.color.button_background_color'))
          .fontColor(this.translucent ? $r('sys.color.font_primary') : $r('app.color.button_foreground_color'))
          .fontSize(this.fontSize)
          .borderColor(Color.Transparent)
          .borderWidth(0)
          .borderRadius(this.barHeight / 2)
          .padding(0)
          .width(this.barWidth)
          .height(this.barHeight)
          .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
            // 仅在系统安全控件授权成功后读取剪贴板
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
      .width(this.barWidth)
      .height(this.barHeight)
      .borderRadius(this.barHeight / 2)
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}
