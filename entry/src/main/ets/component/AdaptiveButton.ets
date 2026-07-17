import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { hdsMaterial } from '@kit.UIDesignKit';
import { HdsMiniBarButton } from 'hds_button';

export const LIGHT_BUTTON_COLOR = '#2b77d9';
const BUTTON_CONTENT_PADDING = 8;

function getButtonContainerSize(buttonSize: number, contentPadding: number = BUTTON_CONTENT_PADDING): number {
  return buttonSize + contentPadding * 2;
}

function getButtonContainerHeight(buttonHeight: number, contentPadding: number = BUTTON_CONTENT_PADDING,
  barBottomMargin: number = 0): number {
  return getButtonContainerSize(buttonHeight, contentPadding) + barBottomMargin;
}

@Component
export struct AdaptiveTextButton {
  text: ResourceStr = '';
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 18;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = BUTTON_CONTENT_PADDING;
  onButtonClick?: () => void;

  @StorageProp('appColorMode') appColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  private isDarkMode(): boolean {
    return this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isDarkMode()) {
        HdsMiniBarButton({
          onButtonClick: () => {
            this.onButtonClick?.();
          },
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          barWidth: this.barWidth,
          barHeight: this.barHeight,
          contentPadding: this.contentPadding,
          barBottomMargin: this.barBottomMargin
        }) {
          Text(this.text)
            .fontSize(this.fontSize)
            .fontColor($r('app.color.button_text_color'))
        }
      } else {
        Button(this.text)
          .type(ButtonType.Capsule)
          .backgroundColor(LIGHT_BUTTON_COLOR)
          .fontColor(Color.White)
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
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}

@Component
export struct AdaptiveIconButton {
  icon: Resource = $r('app.media.icon_add');
  barWidth: number = 50;
  barHeight: number = 50;
  iconWidth: number = 20;
  iconHeight: number = 20;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = BUTTON_CONTENT_PADDING;
  darkOffsetY: number = 0;
  onButtonClick?: () => void;

  @StorageProp('appColorMode') appColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  private isDarkMode(): boolean {
    return this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  @Builder
  lightIconContent() {
    Image(this.icon)
      .width(this.iconWidth)
      .height(this.iconHeight)
      .fillColor(Color.White)
      .align(Alignment.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isDarkMode()) {
        Stack() {
          HdsMiniBarButton({
            onButtonClick: () => {
              this.onButtonClick?.();
            },
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            barWidth: this.barWidth,
            barHeight: this.barHeight,
            contentPadding: this.contentPadding,
            barBottomMargin: this.barBottomMargin
          }) {
            Image(this.icon)
              .width(this.iconWidth)
              .height(this.iconHeight)
              .fillColor($r('app.color.button_text_color'))
          }
        }
        .translate({ y: this.darkOffsetY })
      } else {
        Button() {
          this.lightIconContent()
        }
        .type(ButtonType.Circle)
        .backgroundColor(LIGHT_BUTTON_COLOR)
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
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}

@Component
export struct AdaptiveMenuTextButton {
  text: ResourceStr = '';
  menuItems: MenuElement[] = [];
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 16;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = 0;

  @StorageProp('appColorMode') appColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  private isDarkMode(): boolean {
    return this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isDarkMode()) {
        HdsMiniBarButton({
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          barWidth: this.barWidth,
          barHeight: this.barHeight,
          contentPadding: this.contentPadding,
          barBottomMargin: this.barBottomMargin
        }) {
          Button(this.text)
            .bindMenu(this.menuItems)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.button_text_color'))
            .width('100%')
            .height('100%')
        }
      } else {
        Button(this.text)
          .type(ButtonType.Capsule)
          .bindMenu(this.menuItems)
          .backgroundColor(LIGHT_BUTTON_COLOR)
          .fontColor(Color.White)
          .fontSize(this.fontSize)
          .borderColor(Color.Transparent)
          .borderWidth(0)
          .borderRadius(this.barHeight / 2)
          .width(this.barWidth)
          .height(this.barHeight)
      }
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}

@Component
export struct AdaptivePasteButton {
  barWidth: number = 150;
  barHeight: number = 50;
  fontSize: number = 16;
  contentPadding: number = BUTTON_CONTENT_PADDING;
  barBottomMargin: number = 0;
  onPaste?: (text: string) => void;
  onPasteError?: (err: BusinessError) => void;

  @StorageProp('appColorMode') appColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  private isDarkMode(): boolean {
    return this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isDarkMode()) {
        HdsMiniBarButton({
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          barWidth: this.barWidth,
          barHeight: this.barHeight,
          contentPadding: this.contentPadding,
          barBottomMargin: this.barBottomMargin
        }) {
          PasteButton()
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.button_text_color'))
            .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
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
      } else {
        PasteButton({
          text: PasteDescription.PASTE,
          buttonType: ButtonType.Capsule
        })
          .backgroundColor(LIGHT_BUTTON_COLOR)
          .fontColor(Color.White)
          .fontSize(this.fontSize)
          .borderColor(Color.Transparent)
          .borderWidth(0)
          .borderRadius(this.barHeight / 2)
          .padding(0)
          .width(this.barWidth)
          .height(this.barHeight)
          .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
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
    }
    .width(getButtonContainerSize(this.barWidth, this.contentPadding))
    .height(getButtonContainerHeight(this.barHeight, this.contentPadding, this.barBottomMargin))
  }
}
