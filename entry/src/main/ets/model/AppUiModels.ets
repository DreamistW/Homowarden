export class AppDropdownOption {
  text: ResourceStr = '';
  value: number = 0;
  formatValue: number | undefined = undefined;

  static create(text: ResourceStr, value: number, formatValue?: number): AppDropdownOption {
    const option = new AppDropdownOption();
    option.text = text;
    option.value = value;
    option.formatValue = formatValue;
    return option;
  }
}
