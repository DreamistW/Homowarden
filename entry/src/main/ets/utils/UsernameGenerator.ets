import { util } from '@kit.ArkTS';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';
import { CryptoUtil } from './CryptoUtil';

const TAG_LENGTH_MIN: number = 5;
const TAG_LENGTH_MAX: number = 8;
const TAG_ALPHABET: string = 'abcdefghijklmnopqrstuvwxyz0123456789';
const NUMBER_DIGITS_MIN: number = 2;
const NUMBER_DIGITS_MAX: number = 4;
const DIGIT_ALPHABET: string = '0123456789';

/** 用户名生成类型 */
export enum UsernameType {
  /** 电子邮箱别名（plus-addressing） */
  EMAIL_ALIAS = 0,
  /** 随机单词 */
  RANDOM_WORD = 1
}

/** 用户名生成参数 */
export interface UsernameGenerateOptions {
  type: UsernameType;
  /** 邮箱别名模式使用的基础邮箱 */
  email: string;
  /** 随机单词模式是否首字母大写 */
  capitalize: boolean;
  /** 随机单词模式是否包含数字 */
  includeNumber: boolean;
}

/**
 * 用户名生成器：邮箱别名采用 plus-addressing，随机单词基于内置英文词表，
 * 均使用系统安全随机源并采用拒绝采样消除模偏差
 */
export class UsernameGenerator {
  private static words: string[] | null = null;

  /** 加载并缓存英文词表（rawfile/wordlist.json） */
  static async ensureWordlist(context: Context): Promise<string[]> {
    if (UsernameGenerator.words !== null) {
      return UsernameGenerator.words;
    }
    try {
      const buffer: Uint8Array = await context.resourceManager.getRawFileContent('wordlist.json');
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const text: string = decoder.decodeToString(buffer);
      const parsed: string[] = JSON.parse(text) as string[];
      if (parsed.length > 0) {
        UsernameGenerator.words = parsed;
      }
      return UsernameGenerator.words === null ? [] : UsernameGenerator.words;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to load wordlist: code=${error.code}, message=${error.message}`);
      UsernameGenerator.words = [];
      return UsernameGenerator.words;
    }
  }

  /**
   * 生成用户名
   * @returns 生成的用户名；邮箱非法时返回空串
   */
  static async generate(opts: UsernameGenerateOptions, context: Context): Promise<string> {
    if (opts.type === UsernameType.EMAIL_ALIAS) {
      return UsernameGenerator.generateEmailAlias(opts.email);
    }
    const words: string[] = await UsernameGenerator.ensureWordlist(context);
    return UsernameGenerator.generateRandomWord(words, opts.capitalize, opts.includeNumber);
  }

  /** 生成电子邮箱别名：base+随机标签@domain。邮箱非法或 base 为空时返回空串 */
  private static async generateEmailAlias(email: string): Promise<string> {
    const trimmed: string = (email ?? '').trim();
    const at: number = trimmed.indexOf('@');
    if (at <= 0) {
      return '';
    }
    let local: string = trimmed.substring(0, at);
    const domain: string = trimmed.substring(at);
    const plus: number = local.indexOf('+');
    if (plus >= 0) {
      local = local.substring(0, plus);
    }
    if (local.length === 0) {
      return '';
    }
    const tagLength: number =
      TAG_LENGTH_MIN + await UsernameGenerator.randomIndex(TAG_LENGTH_MAX - TAG_LENGTH_MIN + 1);
    const tag: string = await UsernameGenerator.randomString(TAG_ALPHABET, tagLength);
    return `${local}+${tag}${domain}`;
  }

  /** 从词表随机选取一个单词，按需首字母大写并追加随机数字 */
  private static async generateRandomWord(
    words: string[], capitalize: boolean, includeNumber: boolean): Promise<string> {
    if (words.length === 0) {
      return '';
    }
    const index: number = await UsernameGenerator.randomIndex(words.length);
    let word: string = words[index];
    if (capitalize && word.length > 0) {
      word = word.charAt(0).toUpperCase() + word.substring(1);
    }
    if (includeNumber) {
      const digitCount: number =
        NUMBER_DIGITS_MIN + await UsernameGenerator.randomIndex(NUMBER_DIGITS_MAX - NUMBER_DIGITS_MIN + 1);
      word = word + await UsernameGenerator.randomString(DIGIT_ALPHABET, digitCount);
    }
    return word;
  }

  /** 按字符池与长度生成随机串，拒绝采样消除模偏差 */
  private static async randomString(pool: string, length: number): Promise<string> {
    let result: string = '';
    for (let i = 0; i < length; i++) {
      result += pool.charAt(await UsernameGenerator.randomIndex(pool.length));
    }
    return result;
  }

  /** 返回 [0, range) 内的安全随机整数，拒绝采样消除模偏差 */
  private static async randomIndex(range: number): Promise<number> {
    if (range <= 1) {
      return 0;
    }
    // 用足够多的字节覆盖 range，避免 range > 256 时 limit 为 0 导致死循环
    let byteCount: number = 1;
    let space: number = 256;
    while (space < range) {
      byteCount++;
      space *= 256;
    }
    const limit: number = space - (space % range);
    let value: number = 0;
    do {
      const bytes: Uint8Array = await CryptoUtil.generateRandom(byteCount);
      value = 0;
      for (let i = 0; i < byteCount; i++) {
        value = value * 256 + bytes[i];
      }
    } while (value >= limit);
    return value % range;
  }
}
