import { AppDropdownOption } from '../model/AppUiModels';

/** 将业务选项适配为 ArkUI Select，并统一处理资源文本和无障碍文本 */
@Component
export struct AppDropdown {
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

  private selectOptions(): SelectOption[] {
    const result: SelectOption[] = [];
    for (const option of this.options) {
      const selectOption: SelectOption = { value: this.resolveOptionText(option) };
      result.push(selectOption);
    }
    return result;
  }

  private resolveOptionText(option: AppDropdownOption): string {
    if (typeof option.text === 'string') {
      return option.text;
    }
    if (option.formatValue !== undefined) {
      // 带数量的资源必须传入格式化参数，不能只按资源 ID 读取模板
      return this.getUIContext().getHostContext()?.resourceManager.getStringSync(option.text.id,
        option.formatValue) ?? '';
    }
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(option.text) ?? '';
  }

  private selectedText(): string {
    const index = this.selectedIndex();
    const option = this.options[index];
    if (option === undefined) {
      return '';
    }
    return this.resolveOptionText(option);
  }

  private resolvedAccessibilityLabel(): string {
    if (typeof this.accessibilityLabel === 'string') {
      return this.accessibilityLabel;
    }
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(this.accessibilityLabel) ?? '';
  }

  build() {
    Select(this.selectOptions())
      .selected(this.selectedIndex())
      .value(this.selectedText())
      .font({ size: 14, weight: FontWeight.Regular })
      .selectedOptionFont({ size: this.optionFontSize, weight: FontWeight.Regular })
      .selectedOptionFontColor($r('app.color.brand_accent_color'))
      .optionFont({ size: this.optionFontSize, weight: FontWeight.Regular })
      .menuBackgroundColor($r('app.color.menu_background_color'))
      .menuBackgroundBlurStyle(BlurStyle.NONE)
      .enabled(!this.disabled)
      .width('100%')
      .height(40)
      .accessibilityText(this.resolvedAccessibilityLabel())
      .onSelect((index: number) => {
        // 对外回传稳定业务值，调用方不依赖选项顺序
        const option = this.options[index];
        if (option !== undefined) {
          this.onChange(option.value);
        }
      })
  }
}
