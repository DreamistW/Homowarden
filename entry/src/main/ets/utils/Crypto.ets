import { argon2Hash, HashOption } from '@huozhiniao/argon2';
import { Logger } from '@nzy/logger';
import { buffer, util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { CryptoJS } from '@ohos/crypto-js'

/**
 * 加密工具类
 * 使用CryptoArchitectureKit和@huozhiniao/argon2实现加解密
 */
export class Crypto {
  /**
   * 生成随机盐（Base64字符串）
   */
  static async generateSalt(length: number = 32): Promise<string> {
    let rand = cryptoFramework.createRandom();
    let seed = new Uint8Array([1, 2, 3]);
    rand.setSeed({ data: seed });
    let randOutput = await rand.generateRandom(length);
    return new util.Base64Helper().encodeToStringSync(randOutput.data, util.Type.BASIC);
  }

  /**
   * 生成随机IV（Base64字符串）
   */
  static async generateIV(length: number = 16): Promise<string> {
    let rand = cryptoFramework.createRandom();
    let seed = new Uint8Array([1, 2, 3]);
    rand.setSeed({ data: seed });
    let randOutput = await rand.generateRandom(length);
    return new util.Base64Helper().encodeToStringSync(randOutput.data, util.Type.BASIC);
  }

  /**
   * PBKDF2密钥派生
   * @param password 明文密码
   * @param salt 盐
   * @param iterations 迭代次数
   * @param keyLen 派生密钥长度（字节）
   * @returns Base64字符串
   */
  static deriveKeyPBKDF2(password: string | Uint8Array, salt: string, iterations: number, keyLen: number = 32): Promise<string> {
    const saltBuffer = new util.TextEncoder().encodeInto(salt);
    let spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: password,
      salt: saltBuffer,
      iterations: iterations,
      keySize: keyLen
    }
    let kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
    let kdfPromise = kdf.generateSecret(spec);
    return kdfPromise.then((secret) => {
      return new util.Base64Helper().encodeToStringSync(secret.data, util.Type.BASIC);
    })
  }

  /**
   * Argon2id密钥派生
   * @param password 明文密码
   * @param salt 盐（Base64字符串）
   * @param iterations 迭代次数
   * @param memory 内存（MB）
   * @param parallelism 并行度
   * @param keyLen 派生密钥长度（字节）
   * @returns Base64字符串
   */
  static async deriveKeyArgon2id(password: string, salt: string, iterations: number, memory: number,
    parallelism: number, keyLen: number = 32): Promise<string> {
    let passwordBuffer = new util.TextEncoder().encodeInto(password.toLowerCase());
    let saltBuffer = new util.TextEncoder().encodeInto(salt.toLowerCase());

    const option: HashOption = {
      timeCost: iterations,
      memoryCost: memory,
      parallelism: parallelism,
      hashLength: keyLen,
      argon2Type: 2, // Argon2id
      argon2Version: 19
    };
    const result = argon2Hash(passwordBuffer, saltBuffer, option);
    // result.encoded为base64字符串
    return result.encoded;
  }

  /**
   * AES-256-CBC加密
   * @param data 明文
   * @param key Base64密钥
   * @param iv Base64 IV
   * @returns Base64密文
   */
  static async encryptAES(data: string, key: string, iv: string): Promise<string> {
    // 解析Base64密钥和IV
    const keyWordArray = CryptoJS.enc.Base64.parse(key);
    const ivWordArray = CryptoJS.enc.Base64.parse(iv);
    // 明文转为WordArray
    const dataWordArray = CryptoJS.enc.Utf8.parse(data);
    // 执行加密
    const encrypted = CryptoJS.AES.encrypt(dataWordArray, keyWordArray, {
      iv: ivWordArray,
      mode: CryptoJS.mode.CBC,
      padding: CryptoJS.pad.Pkcs7
    });
    // 返回Base64密文
    return encrypted.ciphertext.toString(CryptoJS.enc.Base64);
  }

  /**
   * AES-256-CBC解密
   * @param encryptedData Base64密文
   * @param key Base64密钥
   * @param iv Base64 IV
   * @returns 明文
   */
  static async decryptAES(encryptedData: string, key: string, iv: string): Promise<string> {
    // 解析Base64密钥和IV
    const keyWordArray = CryptoJS.enc.Base64.parse(key);
    const ivWordArray = CryptoJS.enc.Base64.parse(iv);
    // 解析Base64密文
    const encryptedWordArray = CryptoJS.enc.Base64.parse(encryptedData);
    // 构造CipherParams对象
    const cipherParams = CryptoJS.lib.CipherParams.create({
      ciphertext: encryptedWordArray
    });
    // 执行解密
    const decrypted = CryptoJS.AES.decrypt(cipherParams, keyWordArray, {
      iv: ivWordArray,
      mode: CryptoJS.mode.CBC,
      padding: CryptoJS.pad.Pkcs7
    });
    // 返回明文字符串
    return decrypted.toString(CryptoJS.enc.Utf8);
  }

  /**
   * SHA256哈希
   */
  static sha256(data: string): string {
    return CryptoJS.SHA256(data).toString(CryptoJS.enc.Hex);
  }

  /**
   * HMAC-SHA256
   */
  static hmacSha256(data: string, key: string): string {
    return CryptoJS.HmacSHA256(data, key).toString(CryptoJS.enc.Hex);
  }

  /**
   * 加密字符串（自动生成IV）
   */
  static async encryptString(data: string, key: string): Promise<EncryptedStringResult> {
    const iv = await Crypto.generateIV();
    let encrypted = '';
    Crypto.encryptAES(data, key, iv).then((result) => {
      encrypted = result;
    });
    return { encrypted, iv };
  }

  /**
   * 解密字符串
   */
  static async decryptString(encrypted: string, key: string, iv: string): Promise<string> {
    return Crypto.decryptAES(encrypted, key, iv);
  }

  /**
   * 清理敏感数据
   */
  static clearSensitiveData(data: string): void {
    data = "";
    Logger.debug('Sensitive data cleared');
  }
}

/**
 * Argon2派生结果类型（@huozhiniao/argon2）
 */
export interface Argon2Result {
  hash: string; // base64
  encoded: string;
}

export interface EncryptedStringResult {
  encrypted: string;
  iv: string;
}
