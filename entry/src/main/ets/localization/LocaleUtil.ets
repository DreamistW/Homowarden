import { i18n } from '@kit.LocalizationKit';

/** 提供与当前系统语言相关的请求头、日期和姓名格式化能力。 */
export class LocaleUtil {
  static getLanguage(): string {
    const language: string = i18n.System.getSystemLanguage();
    return language.length > 0 ? language : 'en';
  }

  static getAcceptLanguage(): string {
    const language: string = LocaleUtil.getLanguage();
    const separator: number = language.indexOf('-');
    if (separator > 0) {
      // 同时携带完整语言标签和较低权重的基础语言，便于服务端降级匹配。
      const baseLanguage: string = language.substring(0, separator);
      return `${language},${baseLanguage};q=0.9`;
    }
    return language;
  }

  static formatDateTime(value: string | null | undefined): string {
    if (value === null || value === undefined || value.length === 0) {
      return '---';
    }
    const date: Date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return value;
    }
    const year: number = date.getFullYear();
    const month: string = LocaleUtil.padDatePart(date.getMonth() + 1);
    const day: string = LocaleUtil.padDatePart(date.getDate());
    const hour: string = LocaleUtil.padDatePart(date.getHours());
    const minute: string = LocaleUtil.padDatePart(date.getMinutes());
    const second: string = LocaleUtil.padDatePart(date.getSeconds());
    return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
  }

  private static padDatePart(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  static formatIdentityName(firstName: string, lastName: string): string {
    const language: string = LocaleUtil.getLanguage().toLowerCase();
    // 中日韩姓名通常姓在前，其他语言沿用名在前的顺序。
    if (language.startsWith('zh') || language.startsWith('ja') || language.startsWith('ko')) {
      return `${lastName}${firstName}`.trim();
    }
    return `${firstName} ${lastName}`.trim();
  }
}
