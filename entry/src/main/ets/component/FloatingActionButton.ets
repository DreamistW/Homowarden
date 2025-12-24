import { IBestIcon } from "@ibestservices/ibest-ui";

@Component
export struct FloatingActionButton {
  icon: string = '';
  onTap?: () => void;

  build() {
    IBestIcon({
      name: this.icon,
      iconSize: 24
    })
    .width(56)
    .height(56)
    .backgroundColor('#007AFF')
    .borderRadius(28)
    .position({ x: '85%', y: '85%' })
    .onClick(() => {
      this.onTap?.();
    })
  }
} 