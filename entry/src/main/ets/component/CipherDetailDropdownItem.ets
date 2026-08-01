import { AppDropdown } from './AppDropdown';
import { AppDropdownOption } from '../model/AppUiModels';

@Component
export struct CipherDetailDropdownItem {
  // 文本标题
  @Prop label: ResourceStr;
  // 显示文本内容
  @Prop content: ResourceStr;
  // 下拉菜单选项
  @Prop dropdownOptions: AppDropdownOption[];
  // 下拉菜单组ID
  @Prop groupId: string;
  // 当前选中的值
  @Prop selectedValue: number;
  // 值变化回调
  onValueChange?: (value: number) => void;
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
          AppDropdown({
            options: this.dropdownOptions,
            value: this.selectedValue,
            accessibilityLabel: this.label,
            onChange: (value: number) => {
              if (this.onValueChange) {
                this.onValueChange(value);
              }
            }
          })
        }
        .layoutWeight(1)
        .margin({ left: 16, right: 16 })
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
