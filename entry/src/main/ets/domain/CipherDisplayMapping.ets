import { CardBrandType, IdentityTitleType } from '../utils/Constants';

/** 卡片品牌解析结果，保留无法识别的原始值以兼容历史数据。 */
export class CardBrandMappingResult {
  type: CardBrandType;
  originalValue: string;
  recognized: boolean;

  constructor(type: CardBrandType, originalValue: string, recognized: boolean) {
    this.type = type;
    this.originalValue = originalValue;
    this.recognized = recognized;
  }
}

/** 身份称谓解析结果，保留无法识别的原始值以兼容历史数据。 */
export class IdentityTitleMappingResult {
  type: IdentityTitleType;
  originalValue: string;
  recognized: boolean;

  constructor(type: IdentityTitleType, originalValue: string, recognized: boolean) {
    this.type = type;
    this.originalValue = originalValue;
    this.recognized = recognized;
  }
}

/** 在持久化字符串、业务枚举与本地化显示文本之间转换 Cipher 字段。 */
export class CipherDisplayMapping {
  static cardBrandLabel(value: string | null | undefined): ResourceStr {
    const mapping: CardBrandMappingResult = CipherDisplayMapping.readCardBrand(value);
    if (!mapping.recognized) {
      return mapping.originalValue;
    }
    switch (mapping.type) {
      case CardBrandType.NONE: return $r('app.string.common_none');
      case CardBrandType.VISA: return $r('app.string.card_visa');
      case CardBrandType.MASTER: return $r('app.string.card_mastercard');
      case CardBrandType.AME: return $r('app.string.card_amex');
      case CardBrandType.DISCOVER: return $r('app.string.card_discover');
      case CardBrandType.DINERS: return $r('app.string.card_diners');
      case CardBrandType.JCB: return $r('app.string.card_jcb');
      case CardBrandType.MAESTRO: return $r('app.string.card_maestro');
      case CardBrandType.UNIONPAY: return $r('app.string.card_unionpay');
      case CardBrandType.RUPAY: return $r('app.string.card_rupay');
      default: return $r('app.string.common_other');
    }
  }

  static identityTitleLabel(value: string | null | undefined): ResourceStr {
    const mapping: IdentityTitleMappingResult = CipherDisplayMapping.readIdentityTitle(value);
    if (!mapping.recognized) {
      return mapping.originalValue;
    }
    switch (mapping.type) {
      case IdentityTitleType.NONE: return $r('app.string.common_none');
      case IdentityTitleType.MR: return $r('app.string.identity_mr');
      case IdentityTitleType.MRS: return $r('app.string.identity_mrs');
      case IdentityTitleType.MISS: return $r('app.string.identity_ms');
      case IdentityTitleType.MX: return $r('app.string.identity_mx');
      default: return $r('app.string.identity_dr');
    }
  }

  static readCardBrand(value: string | null | undefined): CardBrandMappingResult {
    const original: string = value ?? '';
    // 兼容不同客户端写入的空格、连字符、别名及旧中文值。
    const normalized: string = original.trim().toLowerCase().replace(new RegExp('[ _-]', 'g'), '');
    switch (normalized) {
      case '': return new CardBrandMappingResult(CardBrandType.NONE, original, true);
      case 'visa': return new CardBrandMappingResult(CardBrandType.VISA, original, true);
      case 'mastercard': return new CardBrandMappingResult(CardBrandType.MASTER, original, true);
      case 'americanexpress':
      case 'amex': return new CardBrandMappingResult(CardBrandType.AME, original, true);
      case 'discover': return new CardBrandMappingResult(CardBrandType.DISCOVER, original, true);
      case 'dinersclub': return new CardBrandMappingResult(CardBrandType.DINERS, original, true);
      case 'jcb': return new CardBrandMappingResult(CardBrandType.JCB, original, true);
      case 'maestro': return new CardBrandMappingResult(CardBrandType.MAESTRO, original, true);
      case 'unionpay':
      case '银联': return new CardBrandMappingResult(CardBrandType.UNIONPAY, original, true);
      case 'rupay': return new CardBrandMappingResult(CardBrandType.RUPAY, original, true);
      case 'other':
      case '其他': return new CardBrandMappingResult(CardBrandType.OTHER, original, true);
      default: return new CardBrandMappingResult(CardBrandType.OTHER, original, false);
    }
  }

  static writeCardBrand(type: CardBrandType, originalValue: string = '', changed: boolean = true): string {
    // 未编辑时回写原值，避免把未知品牌破坏性归一化为 Other。
    if (!changed) {
      return originalValue;
    }
    switch (type) {
      case CardBrandType.VISA: return 'Visa';
      case CardBrandType.MASTER: return 'Mastercard';
      case CardBrandType.AME: return 'American Express';
      case CardBrandType.DISCOVER: return 'Discover';
      case CardBrandType.DINERS: return 'Diners Club';
      case CardBrandType.JCB: return 'JCB';
      case CardBrandType.MAESTRO: return 'Maestro';
      case CardBrandType.UNIONPAY: return 'UnionPay';
      case CardBrandType.RUPAY: return 'RuPay';
      case CardBrandType.OTHER: return 'Other';
      default: return '';
    }
  }

  static readIdentityTitle(value: string | null | undefined): IdentityTitleMappingResult {
    const original: string = value ?? '';
    // 服务端字段可能来自其他客户端，需同时接受规范缩写和旧中文值。
    const normalized: string = original.trim().toUpperCase();
    switch (normalized) {
      case '': return new IdentityTitleMappingResult(IdentityTitleType.NONE, original, true);
      case 'MR':
      case '先生': return new IdentityTitleMappingResult(IdentityTitleType.MR, original, true);
      case 'MRS':
      case '夫人': return new IdentityTitleMappingResult(IdentityTitleType.MRS, original, true);
      case 'MS':
      case 'MISS':
      case '女士': return new IdentityTitleMappingResult(IdentityTitleType.MISS, original, true);
      case 'MX': return new IdentityTitleMappingResult(IdentityTitleType.MX, original, true);
      case 'DR':
      case '博士': return new IdentityTitleMappingResult(IdentityTitleType.DR, original, true);
      default: return new IdentityTitleMappingResult(IdentityTitleType.NONE, original, false);
    }
  }

  static writeIdentityTitle(type: IdentityTitleType, originalValue: string = '', changed: boolean = true): string {
    // 未编辑时保留未知称谓，确保跨客户端数据可无损往返。
    if (!changed) {
      return originalValue;
    }
    switch (type) {
      case IdentityTitleType.MR: return 'MR';
      case IdentityTitleType.MRS: return 'MRS';
      case IdentityTitleType.MISS: return 'MS';
      case IdentityTitleType.MX: return 'MX';
      case IdentityTitleType.DR: return 'DR';
      default: return '';
    }
  }
}
