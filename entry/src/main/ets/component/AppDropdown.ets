import { AppDropdownOption } from '../model/AppUiModels';

@Component
export struct AppDropdown {
  @Prop options: AppDropdownOption[] = [];
  @Prop value: number = 0;
  @Prop disabled: boolean = false;
  @Prop accessibilityLabel: ResourceStr = '';
  @Prop optionFontSize: number = 14;
  onChange: (value: number) => void = () => {};

  private selectedIndex(): number {
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
      .optionFont({ size: this.optionFontSize, weight: FontWeight.Regular })
      .enabled(!this.disabled)
      .width('100%')
      .height(40)
      .accessibilityText(this.resolvedAccessibilityLabel())
      .onSelect((index: number) => {
        const option = this.options[index];
        if (option !== undefined) {
          this.onChange(option.value);
        }
      })
  }
}
