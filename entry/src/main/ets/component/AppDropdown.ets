import { AppDropdownOption } from '../model/AppUiModels';

/** 对两个无障碍文本重载分别收窄类型，同时保留语言资源引用。 */
class DropdownAccessibilityModifier implements AttributeModifier<SelectAttribute> {
  private label: ResourceStr;

  constructor(label: ResourceStr) {
    this.label = label;
  }

  applyNormalAttribute(attribute: SelectAttribute): void {
    if (typeof this.label === 'string') {
      attribute.accessibilityText(this.label);
    } else {
      attribute.accessibilityText(this.label);
    }
  }
}

/** 将业务选项适配为 ArkUI Select，并统一处理资源文本和无障碍文本 */
@Component
export struct AppDropdown {
  @StorageLink('localeRevision') localeRevision: number = 0;
  @Prop options: AppDropdownOption[] = [];
  @Prop value: number = 0;
  @Prop disabled: boolean = false;
  @Prop accessibilityLabel: ResourceStr = '';
  @Prop optionFontSize: number = 14;
  onChange: (value: number) => void = () => {};

  private selectedIndex(): number {
    // 页面保存业务枚举值，原生 Select 使用数组下标，两者不能直接混用
    const index = this.options.findIndex((option: AppDropdownOption) => option.value === this.value);
    return index < 0 ? 0 : index;
  }

  private selectOptions(_revision: number): SelectOption[] {
    const result: SelectOption[] = [];
    for (const option of this.options) {
      // 保留资源引用，让 ArkUI 跟随应用语言解析，包含资源自身的格式化参数。
      const selectOption: SelectOption = { value: option.text };
      result.push(selectOption);
    }
    return result;
  }

  private selectedText(_revision: number): ResourceStr {
    const index = this.selectedIndex();
    const option = this.options[index];
    if (option === undefined) {
      return '';
    }
    return option.text;
  }

  build() {
    Select(this.selectOptions(this.localeRevision))
      .selected(this.selectedIndex())
      .value(this.selectedText(this.localeRevision))
      .font({ size: 14, weight: FontWeight.Regular })
      .selectedOptionFont({ size: this.optionFontSize, weight: FontWeight.Regular })
      .selectedOptionFontColor($r('app.color.brand_accent_color'))
      .optionFont({ size: this.optionFontSize, weight: FontWeight.Regular })
      .menuBackgroundColor($r('app.color.menu_background_color'))
      .menuBackgroundBlurStyle(BlurStyle.NONE)
      .enabled(!this.disabled)
      .width('100%')
      .height(40)
      .attributeModifier(new DropdownAccessibilityModifier(this.accessibilityLabel))
      .onSelect((index: number) => {
        // 对外回传稳定业务值，调用方不依赖选项顺序
        const option = this.options[index];
        if (option !== undefined) {
          this.onChange(option.value);
        }
      })
  }
}
