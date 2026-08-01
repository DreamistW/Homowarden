/** 下拉选项模型，支持普通文本和带数值占位符的资源文本。 */
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
