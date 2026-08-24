import { CryptoUtil } from './CryptoUtil';

/** 密码生成参数 */
export interface PasswordGenerateOptions {
  /** 密码总长度 */
  length: number;
  /** 是否包含大写字母 A-Z */
  upperOn: boolean;
  /** 是否包含小写字母 a-z */
  lowerOn: boolean;
  /** 是否包含数字 0-9 */
  digitOn: boolean;
  /** 是否包含符号 */
  symbolOn: boolean;
  /** 数字最小个数 */
  minDigits: number;
  /** 符号最小个数 */
  minSymbols: number;
}

const UPPER_CHARS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const LOWER_CHARS: string = 'abcdefghijklmnopqrstuvwxyz';
const DIGIT_CHARS: string = '0123456789';
const SYMBOL_CHARS: string = '!@#$%^&*';

/**
 * 密码生成器：基于系统安全随机源，支持按字符类别开关与最小个数约束，
 * 采用拒绝采样消除模偏差，并通过 Fisher-Yates 洗牌打散固定类别字符
 */
export class PasswordGenerator {
  /**
   * 生成密码。当没有任何字符类别开启时返回空串
   */
  static async generate(opts: PasswordGenerateOptions): Promise<string> {
    const length: number = Math.max(0, Math.floor(opts.length));
    if (length <= 0) {
      return '';
    }

    const enabledPools: string[] = [];
    if (opts.upperOn) {
      enabledPools.push(UPPER_CHARS);
    }
    if (opts.lowerOn) {
      enabledPools.push(LOWER_CHARS);
    }
    if (opts.digitOn) {
      enabledPools.push(DIGIT_CHARS);
    }
    if (opts.symbolOn) {
      enabledPools.push(SYMBOL_CHARS);
    }
    if (enabledPools.length === 0) {
      return '';
    }
    const unionPool: string = enabledPools.join('');

    // 关闭的类别其最小个数按 0 处理，并保证二者之和不超过总长度
    const effectiveDigitMin: number = opts.digitOn ? Math.min(Math.max(0, opts.minDigits), length) : 0;
    const effectiveSymbolMin: number =
      opts.symbolOn ? Math.min(Math.max(0, opts.minSymbols), length - effectiveDigitMin) : 0;

    const chars: string[] = [];
    for (let i = 0; i < effectiveDigitMin; i++) {
      chars.push(await PasswordGenerator.pickFrom(DIGIT_CHARS));
    }
    for (let i = 0; i < effectiveSymbolMin; i++) {
      chars.push(await PasswordGenerator.pickFrom(SYMBOL_CHARS));
    }
    const remaining: number = length - effectiveDigitMin - effectiveSymbolMin;
    for (let i = 0; i < remaining; i++) {
      chars.push(await PasswordGenerator.pickFrom(unionPool));
    }

    await PasswordGenerator.shuffle(chars);
    return chars.join('');
  }

  /** 从字符池中按安全随机选取一个字符，拒绝采样消除模偏差 */
  private static async pickFrom(pool: string): Promise<string> {
    const poolSize: number = pool.length;
    // 256 内能均匀分配给 poolSize 的最大上界
    const limit: number = 256 - (256 % poolSize);
    let value: number = 0;
    do {
      const bytes: Uint8Array = await CryptoUtil.generateRandom(1);
      value = bytes[0];
    } while (value >= limit);
    return pool.charAt(value % poolSize);
  }

  /** Fisher-Yates 洗牌，下标通过拒绝采样选取 */
  private static async shuffle(chars: string[]): Promise<void> {
    for (let i = chars.length - 1; i > 0; i--) {
      const range: number = i + 1;
      const limit: number = 256 - (256 % range);
      let value: number = 0;
      do {
        const bytes: Uint8Array = await CryptoUtil.generateRandom(1);
        value = bytes[0];
      } while (value >= limit);
      const j: number = value % range;
      const tmp: string = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }
  }
}
