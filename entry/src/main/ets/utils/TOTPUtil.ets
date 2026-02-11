import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Logger } from '@nzy/logger';

/**
 * otpauth URL 解析结果
 */
export interface OtpAuthResult {
  secret: string;
  issuer?: string;
  account?: string;
}

/**
 * TOTP (Time-based One-Time Password) 工具类
 * 基于RFC 6238标准实现
 */
export class TOTPUtil {
  private static readonly TIME_STEP: number = 30; // 30秒
  private static readonly CODE_DIGITS: number = 6; // 6位验证码
  private static readonly BASE32_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /**
   * 生成TOTP验证码
   * @param secret Base32编码的密钥
   * @returns 6位验证码
   */
  static async generateTOTP(secret: string): Promise<string> {
    try {
      if (!secret || secret.trim() === '') {
        return '------';
      }

      // 检查是否是otpauth URL，如果是则提取密钥
      let actualSecret = secret;
      if (secret.startsWith('otpauth://totp/')) {
        Logger.info('Detected otpauth URL, extracting secret');
        const parsed = TOTPUtil.parseOtpAuthUrl(secret);
        actualSecret = parsed.secret;
        // Logger.info(`Extracted secret: ${actualSecret}`);
      }

      if (!actualSecret || actualSecret.trim() === '') {
        Logger.error('No valid secret found');
        return '------';
      }

      // 1. Base32解码密钥
      const keyBytes = TOTPUtil.base32Decode(actualSecret);
      if (keyBytes.length === 0) {
        Logger.error('Failed to decode Base32 secret');
        return '------';
      }

      Logger.info(`TOTP key length: ${keyBytes.length} bytes`);

      // 2. 计算时间计数器
      const timeCounter = Math.floor(Date.now() / 1000 / TOTPUtil.TIME_STEP);
      Logger.info(`TOTP time counter: ${timeCounter}`);

      // 3. 将时间计数器转换为8字节数组（大端序）
      const timeBytes = TOTPUtil.uint64ToBytes(timeCounter);

      // 4. HMAC-SHA1计算
      const mac = cryptoFramework.createMac('SHA1');

      // 生成SymKey
      const symKey = await TOTPUtil.genSymKeyByData(keyBytes);

      // 初始化MAC
      await mac.init(symKey);

      // 更新数据
      const timeBlob: cryptoFramework.DataBlob = { data: timeBytes };
      await mac.update(timeBlob);

      // 计算HMAC
      const hmacResult = await mac.doFinal();
      Logger.info(`HMAC result length: ${hmacResult.data.length}`);

      // 5. 动态截断
      const hmacData = hmacResult.data;
      const offset = hmacData[hmacData.length - 1] & 0x0f;

      const binary = ((hmacData[offset] & 0x7f) << 24)
        | ((hmacData[offset + 1] & 0xff) << 16)
        | ((hmacData[offset + 2] & 0xff) << 8)
        | (hmacData[offset + 3] & 0xff);

      const code = binary % Math.pow(10, TOTPUtil.CODE_DIGITS);

      // 6. 格式化为6位数字
      const result = code.toString().padStart(TOTPUtil.CODE_DIGITS, '0');
      // Logger.info(`TOTP generated: ${result}`);
      return result;
    } catch (error) {
      Logger.error(`TOTP generation failed: ${JSON.stringify(error)}`);
      return '------';
    }
  }

  /**
   * 从字节数据生成对称密钥
   * @param symKeyData 密钥字节序列
   * @returns SymKey对象
   */
  private static async genSymKeyByData(symKeyData: Uint8Array): Promise<cryptoFramework.SymKey> {
    try {
      Logger.info(`genSymKeyByData: input length = ${symKeyData.length} bytes`);

      // AES256要求密钥长度为32字节
      // 如果密钥长度不是32字节，需要填充或截断
      let keyData = symKeyData;

      if (keyData.length < 32) {
        // 填充零到32字节
        const padded = new Uint8Array(32);
        padded.set(keyData, 0);
        keyData = padded;
        Logger.info(`Key padded from ${symKeyData.length} to 32 bytes`);
      } else if (keyData.length > 32) {
        // 截断到32字节
        keyData = keyData.slice(0, 32);
        Logger.info(`Key truncated from ${symKeyData.length} to 32 bytes`);
      }

      Logger.info(`genSymKeyByData: final length = ${keyData.length} bytes`);

      const symKeyBlob: cryptoFramework.DataBlob = { data: keyData };
      const aesGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const symKey = await aesGenerator.convertKey(symKeyBlob);
      return symKey;
    } catch (error) {
      Logger.error(`Failed to generate symmetric key: ${JSON.stringify(error)}`);
      throw new Error(error);
    }
  }

  /**
   * 获取剩余秒数
   * @returns 剩余秒数（1-30）
   */
  static getRemainingSeconds(): number {
    const remaining = TOTPUtil.TIME_STEP - (Math.floor(Date.now() / 1000) % TOTPUtil.TIME_STEP);
    return remaining === 0 ? TOTPUtil.TIME_STEP : remaining;
  }

  /**
   * Base32解码
   * @param encoded Base32编码的字符串
   * @returns 解码后的字节数组
   */
  private static base32Decode(encoded: string): Uint8Array {
    try {
      // Logger.info(`Base32 decode input: ${encoded}`);
      // 清理输入：移除空格、连字符，转大写
      const cleanEncoded = encoded.replace(/\s/g, '').replace(/-/g, '').toUpperCase();
      // Logger.info(`Base32 clean input: ${cleanEncoded}, length: ${cleanEncoded.length}`);

      // 检查有效字符
      const bits: number[] = [];
      for (const char of cleanEncoded) {
        const val = TOTPUtil.BASE32_ALPHABET.indexOf(char);
        if (val === -1) {
          Logger.warn(`Invalid Base32 character: ${char}`);
          continue;
        }
        // 将每个字符转换为5位二进制
        bits.push((val >> 4) & 1);
        bits.push((val >> 3) & 1);
        bits.push((val >> 2) & 1);
        bits.push((val >> 1) & 1);
        bits.push(val & 1);
      }

      // 将位转换为字节
      const bytes = new Uint8Array(Math.floor(bits.length / 8));
      for (let i = 0; i < bytes.length; i++) {
        bytes[i] = (bits[i * 8] << 7)
          | (bits[i * 8 + 1] << 6)
          | (bits[i * 8 + 2] << 5)
          | (bits[i * 8 + 3] << 4)
          | (bits[i * 8 + 4] << 3)
          | (bits[i * 8 + 5] << 2)
          | (bits[i * 8 + 6] << 1)
          | bits[i * 8 + 7];
      }

      // Logger.info(`Base32 decode output: ${bytes.length} bytes`);
      return bytes;
    } catch (error) {
      Logger.error(`Base32 decode failed: ${JSON.stringify(error)}`);
      return new Uint8Array(0);
    }
  }

  /**
   * 将64位整数转换为8字节数组（大端序）
   * @param num 64位整数
   * @returns 8字节数组
   */
  private static uint64ToBytes(num: number): Uint8Array {
    const bytes = new Uint8Array(8);
    for (let i = 7; i >= 0; i--) {
      bytes[i] = num & 0xff;
      num = Math.floor(num / 256);
    }
    return bytes;
  }

  /**
   * 解析otpauth://totp/ URL
   * @param url otpauth URL
   * @returns 解析后的密钥和参数
   */
  static parseOtpAuthUrl(url: string): OtpAuthResult {
    try {
      if (!url || !url.startsWith('otpauth://totp/')) {
        Logger.warn('Invalid otpauth URL format');
        return { secret: '' };
      }

      // 解析URL格式: otpauth://totp/Issuer:Account?secret=xxx&parameters
      const pathEnd = url.indexOf('?');
      if (pathEnd === -1) {
        return { secret: '' };
      }

      const pathPart = url.substring(15, pathEnd); // 移除 "otpauth://totp/"
      const queryPart = url.substring(pathEnd + 1);

      // 解析路径部分
      let issuer: string | undefined;
      let account: string | undefined;

      const colonIndex = pathPart.indexOf(':');
      if (colonIndex !== -1) {
        issuer = decodeURIComponent(pathPart.substring(0, colonIndex));
        account = decodeURIComponent(pathPart.substring(colonIndex + 1));
      } else {
        account = decodeURIComponent(pathPart);
      }

      // 手动解析查询参数
      const secret = TOTPUtil.extractQueryParam(queryPart, 'secret');

      // Logger.info(`Parsed otpauth URL - issuer: ${issuer}, account: ${account}`);

      const result: OtpAuthResult = { secret };
      if (issuer) {
        result.issuer = issuer;
      }
      if (account) {
        result.account = account;
      }
      return result;
    } catch (error) {
      Logger.error(`Failed to parse otpauth URL: ${JSON.stringify(error)}`);
      return { secret: '' };
    }
  }

  /**
   * 从查询字符串中提取参数值
   * @param queryString 查询字符串（不包含?）
   * @param paramName 参数名
   * @returns 参数值
   */
  private static extractQueryParam(queryString: string, paramName: string): string {
    try {
      const params = queryString.split('&');
      for (const param of params) {
        const equalIndex = param.indexOf('=');
        if (equalIndex !== -1) {
          const name = decodeURIComponent(param.substring(0, equalIndex));
          if (name === paramName) {
            return decodeURIComponent(param.substring(equalIndex + 1));
          }
        }
      }
      return '';
    } catch (error) {
      Logger.error(`Failed to extract query param: ${JSON.stringify(error)}`);
      return '';
    }
  }

  /**
   * 验证密钥格式是否有效
   * @param secret Base32编码的密钥
   * @returns 是否有效
   */
  static isValidSecret(secret: string): boolean {
    if (!secret || secret.trim() === '') {
      return false;
    }

    const cleanSecret = secret.replace(/\s/g, '').replace(/-/g, '').toUpperCase();
    const validPattern = /^[A-Z2-7]+$/;

    if (!validPattern.test(cleanSecret)) {
      return false;
    }

    // Base32编码的密钥长度应该是8的倍数（至少16个字符 = 80位）
    // 但为了兼容性，我们接受较短的密钥
    return cleanSecret.length >= 8;
  }
}
