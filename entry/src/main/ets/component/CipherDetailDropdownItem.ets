import { IBestDropdownItem, IBestDropdownMenu, IBestDropdownMenuOption } from '@ibestservices/ibest-ui';

@Component
export struct CipherDetailDropdownItem {
  // 文本标题
  @Prop label: ResourceStr;
  // 显示文本内容
  @Prop content: ResourceStr;
  // 下拉菜单选项
  @Prop dropdownOptions: IBestDropdownMenuOption[];
  // 下拉菜单组ID
  @Prop groupId: string;
  // 当前选中的值
  @Prop selectedValue: string | number;
  // 值变化回调
  onValueChange?: (value: string | number) => void;
  // 是否编辑模式
  @Prop isEditable: boolean = false;

  private getAccessibilityLabel(): string {
    if (typeof this.label === 'string') {
      return this.label;
    }
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(this.label.id) ?? '';
  }

  build() {
    Row() {
      Text(this.label)
        .fontSize(14)
        .fontColor('#666666')
        .width(112)

      if (this.isEditable) {
        // 编辑模式：显示下拉菜单
        Row() {
          IBestDropdownMenu({ groupId: this.groupId, menuWidthType: "flex" }) {
            IBestDropdownItem({
              groupId: this.groupId,
              options: this.dropdownOptions,
              value: this.selectedValue,
              onChange: value => {
                if (this.onValueChange) {
                  this.onValueChange(value);
                }
              },
            })
              .accessibilityText(this.getAccessibilityLabel())
          }
        }
        .layoutWeight(1)
      } else {
        // 非编辑模式：显示文本
        Text(this.content)
          .fontSize(14)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
