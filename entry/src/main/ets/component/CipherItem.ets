import { Cipher } from '../model/CipherModels.ets';
import { IBestIcon } from "@ibestservices/ibest-ui";
import { CipherItemType } from '../utils/Constants';

@Component
export struct CipherItem {
  cipher: Cipher = {} as Cipher;
  onTap?: () => void;

  @Builder
  CipherTypeIcon() {
    IBestIcon({
      name: this.getTypeIcon(),
      iconSize: 24
    }).margin({ right: 8 })
  }

  private getTypeIcon(): string {
    switch (this.cipher.type) {
      case CipherItemType.LOGIN:
        return 'sign';
      case CipherItemType.NOTE:
        return 'notes-o';
      case CipherItemType.CARD:
        return 'credit-pay';
      case CipherItemType.IDENTITY:
        return 'friends-o';
      default:
        return 'cross';
    }
  }

  build() {
    Row() {
      // 类型图标
      this.CipherTypeIcon()

      // 内容区域
      Column() {
        Text(this.cipher.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.cipher.subtitle)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .margin({ bottom: 8 })
    .onClick(() => {
      this.onTap?.();
    })
  }
} 