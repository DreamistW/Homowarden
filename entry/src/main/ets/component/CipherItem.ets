import { Cipher } from '../model/CipherModels.ets';
import { IBestIcon } from "@ibestservices/ibest-ui";
import { CipherItemType } from '../utils/Constants';

@Component
export struct CipherItem {
  cipher: Cipher = {} as Cipher;
  onTap?: () => void;
  onFavorite?: (isFavorite: boolean) => void;

  @Builder
  CipherTypeIcon() {
    IBestIcon({
      name: this.getTypeIcon(),
      iconSize: 24
    })
  }

  @Builder
  FavoriteButton() {
    IBestIcon({
      name: this.cipher.favorite ? 'star' : 'star-o',
      iconSize: 20,
      onIconClick: ()=>{
        this.onFavorite?.(!this.cipher.favorite);
      }
    })
  }

  private getTypeIcon(): string {
    switch (this.cipher.type) {
      case CipherItemType.LOGIN:
        return 'contact-o';
      case CipherItemType.NOTE:
        return 'notes-o';
      case CipherItemType.CARD:
        return 'credit-pay';
      case CipherItemType.IDENTITY:
        return 'idcard';
      default:
        return 'cross';
    }
  }

  private getSubtitle(): string {
    if (this.cipher.login && this.cipher.login.username) {
      return this.cipher.login.username;
    }
    if (this.cipher.notes) {
      return this.cipher.notes.length > 50 ? 
        this.cipher.notes.substring(0, 50) + '...' : 
        this.cipher.notes;
    }
    return this.getTypeName();
  }

  private getTypeName(): string {
    switch (this.cipher.type) {
      case CipherItemType.LOGIN:
        return '登录';
      case CipherItemType.NOTE:
        return '安全笔记';
      case CipherItemType.CARD:
        return '卡片';
      case CipherItemType.IDENTITY:
        return '身份信息';
      default:
        return '未知';
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
        
        Text(this.getSubtitle())
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 收藏按钮
      this.FavoriteButton()
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .margin({ bottom: 8 })
    .onClick(() => {
      this.onTap?.();
    })
  }
} 