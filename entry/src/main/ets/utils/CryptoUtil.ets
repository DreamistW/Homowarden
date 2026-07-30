import { argon2Hash, HashOption } from '@huozhiniao/argon2';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';

/**
 * 实现登录 KDF、条目 AES-CBC/HMAC 加解密及摘要计算。
 */
export class CryptoUtil {
  /**
   * PBKDF2密钥派生
   * @param password 明文密码
   * @param salt UTF-8 盐文本；登录场景使用规范化邮箱。
   * @param iterations 迭代次数
   * @param keyLen 派生密钥长度（字节）
   * @returns 指定字节长度派生结果的 Base64 文本。
   * @throws 平台 KDF 创建或派生失败时传播异常。
   */
  static deriveKeyPBKDF2(password: string | Uint8Array, salt: string, iterations: number,
    keyLen: number = 32): Promise<string> {
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
      return new util.Base64Helper().encodeToStringSync(secret.data);
    })
  }

  /**
   * HKDF密钥派生
   * @param key 原始密钥
   * @param info 可选 UTF-8 上下文，例如 `enc` 或 `mac`。
   * @param salt 可选 UTF-8 盐；缺失时使用 32 个零字节。
   * @param keyLen 密钥字节长度
   * @returns HKDF-SHA256 EXPAND_ONLY 派生结果的 Base64 文本。
   * @throws 平台 KDF 创建或派生失败时传播异常。
   */
  static deriveKeyHKDF(key: string | Uint8Array, info?: string, salt?: string,
    keyLen: number = 32): Promise<string> {
    let saltBuffer = new Uint8Array(32);
    let infoBuffer = new Uint8Array();
    if (salt) {
      saltBuffer = new util.TextEncoder().encodeInto(salt);
    }
    if (info) {
      infoBuffer = new util.TextEncoder().encodeInto(info);
    }
    const spec: cryptoFramework.HKDFSpec = {
      algName: "HKDF",
      key: key,
      salt: saltBuffer,
      info: infoBuffer,
      keySize: keyLen
    };
    const kdf = cryptoFramework.createKdf('HKDF|SHA256|EXPAND_ONLY');
    const kdfPromise = kdf.generateSecret(spec);
    return kdfPromise.then((secret) => {
      return new util.Base64Helper().encodeToStringSync(secret.data);
    })
  }

  /**
   * Argon2id密钥派生
   * @param password 明文密码
   * @param salt UTF-8 盐文本，内部转为小写；不是 Base64 输入。
   * @param iterations 迭代次数
   * @param memory 内存（MB）
   * @param parallelism 并行度
   * @param keyLen 派生密钥长度（字节）
   * @returns Argon2id 原始 hash 的 Base64 文本。
   * @throws Argon2 参数或计算失败时传播异常。
   */
  static async deriveKeyArgon2id(password: string, salt: string, iterations: number, memory: number,
    parallelism: number, keyLen: number = 32): Promise<string> {
    let passwordBuffer = new util.TextEncoder().encodeInto(password);
    let saltBuffer = new util.TextEncoder().encodeInto(salt.toLowerCase());

    const option: HashOption = {
      timeCost: iterations,
      memoryCost: memory * 1024,
      parallelism: parallelism,
      hashLength: keyLen,
      argon2Type: 2, // Argon2id
      argon2Version: 19
    };
    const result = argon2Hash(passwordBuffer, saltBuffer, option);
    return new util.Base64Helper().encodeToStringSync(new Uint8Array(result.hash));
  }

  /**
   * 转换密钥类型
   * @param symKeyData 要转换的密钥字节序列
   * @returns 密钥类型对象
   */
  static async genSymKeyByData(symKeyData: Uint8Array): Promise<cryptoFramework.SymKey> {
    try {
      const symKeyBlob: cryptoFramework.DataBlob = { data: symKeyData };
      const aesGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const symKey = await aesGenerator.convertKey(symKeyBlob);
      return symKey;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to generate symmetric key, error message: ${error.message}`);
      throw new Error(err);
    }
  }

  /**
   * AES256-CBC解密
   * @param cipherText 完整的密文
   * @param key 对称密钥
   * @returns 解密字节的 Base64 文本，尚未按 UTF-8 解码。
   * @throws 密文格式、Base64、密钥转换或平台解密失败时抛出新 Error。
   */
  static async decryptAESCBC(cipherText: string, key: Uint8Array): Promise<string> {
    try {
      const partsOfText = cipherText.substring(2).split('|');
      const cipherBlob: cryptoFramework.DataBlob =
        { data: new util.Base64Helper().decodeSync(partsOfText[1]) };
      const symKey = await CryptoUtil.genSymKeyByData(key);
      // Logger.info(`cipherText length: ${cipherBlob.data.length}`);
      // Logger.info(`key length: ${key.length}`);
      const decoder = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      const paramSpec: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: { data: new util.Base64Helper().decodeSync(partsOfText[0]) },
      }
      // Logger.info(`iv length: ${paramSpec.iv.data.length}`);
      await decoder.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, paramSpec);
      const decryptedData = await decoder.doFinal(cipherBlob);
      return new util.Base64Helper().encodeToStringSync(decryptedData.data)
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to decrypt, error message: ${error.message}`);
      throw new Error(err);
    }
  }

  /**
   * HMAC-SHA256校验，密文内自带的HMAC与根据MAC Key生成的HMAC进行比较
   * @param cipherText 完整的密文
   * @param macKey 需要比较的MAC Key
   * @returns 密文携带的 HMAC 与计算结果完全相同时为 `true`。
   * @throws 密文格式、Base64 或平台 MAC 计算失败时抛出新 Error。
   */
  static async verifyHMAC(cipherText: string, macKey: Uint8Array): Promise<boolean> {
    const partsOfText = cipherText.substring(2).split('|');
    const ivBytes = new util.Base64Helper().decodeSync(partsOfText[0]);
    const cipherBytes = new util.Base64Helper().decodeSync(partsOfText[1]);
    const macData = new Uint8Array(ivBytes.length + cipherBytes.length);
    macData.set(ivBytes, 0);
    macData.set(cipherBytes, ivBytes.length);
    try {
      let mac = cryptoFramework.createMac('SHA256');
      await mac.init(await CryptoUtil.genSymKeyByData(macKey));
      await mac.update({ data: macData });
      let macResult = await mac.doFinal();
      const macResultStr = new util.Base64Helper().encodeToStringSync(macResult.data);
      if (partsOfText[2] == macResultStr) {
        return true;
      } else {
        return false;
      }
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to verify HMAC, error message: ${error.message}`);
      throw new Error(err);
    }
  }

  /**
   * 解密字段
   * @param cipherText 完整的密文
   * @param symKey 包含HMAC的对称密钥
   * @returns 校验成功后的 UTF-8 明文；空输入或 HMAC 不匹配返回空字符串，处理异常返回错误描述文本。
   */
  static async decryptField(cipherText: string, symKey: string): Promise<string> {
    if (!cipherText || cipherText.length == 0) {
      return '';
    }
    const keyBytes = new util.Base64Helper().decodeSync(symKey);
    // MAC验证
    const macKeyBytes = keyBytes.slice(32);
    try {
      const macResult = await CryptoUtil.verifyHMAC(cipherText, macKeyBytes);
      if (macResult) {
        const plainText = await CryptoUtil.decryptAESCBC(cipherText, keyBytes.slice(0, 32));
        return CryptoUtil.base64DecodeToString(plainText);
      }
      throw new Error('MAC verification failed');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to decrypt, error message: ${error.message}`);
      throw new Error(`Failed to decrypt: ${error.message}`);
    }
  }

  static async decryptCipherKey(cipherKey: string | null | undefined, symKey: string): Promise<string> {
    if (!cipherKey) {
      return symKey;
    }
    const keyBytes = new util.Base64Helper().decodeSync(symKey);
    const macResult = await CryptoUtil.verifyHMAC(cipherKey, keyBytes.slice(32));
    if (!macResult) {
      throw new Error('Cipher key MAC verification failed');
    }
    const decryptedKey = await CryptoUtil.decryptAESCBC(cipherKey, keyBytes.slice(0, 32));
    const decryptedKeyBytes = new util.Base64Helper().decodeSync(decryptedKey);
    if (decryptedKeyBytes.length !== 64) {
      throw new Error('Invalid cipher key length');
    }
    return decryptedKey;
  }

  // Base64字符串解码
  static base64DecodeToString(base64: string): string {
    const bytes = new util.Base64Helper().decodeSync(base64);
    const str = new util.TextDecoder().decodeToString(bytes);
    return str;
  }

  // 生成随机数
  static async generateRandom(len: number): Promise<Uint8Array> {
    let rand = cryptoFramework.createRandom();
    let randOutput = await rand.generateRandom(len);
    return randOutput.data;
  }

  /**
   * AES-256-CBC加密
   * @param plainText 明文
   * @param iv 16 字节初始化向量。
   * @param key 对称密钥
   * @returns AES-256-CBC 密文字节的 Base64 文本；空明文返回空字符串。
   * @throws 密钥转换或平台加密失败时抛出新 Error。
   */
  static async encryptAESCBC(plainText: string, iv: Uint8Array, key: Uint8Array): Promise<string> {
    if (plainText.length == 0) {
      return '';
    }
    try {
      const cipherBlob: cryptoFramework.DataBlob =
        { data: new util.TextEncoder().encodeInto(plainText) };
      let cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      const symKey = await CryptoUtil.genSymKeyByData(key);
      const paramSpec: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: { data: iv },
      }
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, paramSpec);
      let cipherData = await cipher.doFinal(cipherBlob);
      return new util.Base64Helper().encodeToStringSync(cipherData.data);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to encrypt, error message: ${error.message}`);
      throw new Error(err);
    }
  }

  /**
   * 生成HMAC
   * @param iv 与密文一起参与认证的初始化向量。
   * @param cipherText base64密文字符串
   * @param macKey 生成MAC的密钥
   * @returns `iv + cipherBytes` 的 HMAC-SHA256 Base64 文本；空密文返回空字符串。
   * @throws Base64、密钥转换或平台 MAC 计算失败时抛出新 Error。
   */
  static async generateHMAC(iv: Uint8Array, cipherText: string, macKey: Uint8Array): Promise<string> {
    if (cipherText.length == 0) {
      return '';
    }
    try {
      const cipherBytes = new util.Base64Helper().decodeSync(cipherText);
      const macData = new Uint8Array(iv.length + cipherBytes.length);
      macData.set(iv, 0);
      macData.set(cipherBytes, iv.length);
      let mac = cryptoFramework.createMac('SHA256');
      await mac.init(await CryptoUtil.genSymKeyByData(macKey));
      await mac.update({ data: macData });
      let macResult = await mac.doFinal();
      return new util.Base64Helper().encodeToStringSync(macResult.data);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to generate HMAC, error message: ${error.message}`);
      throw new Error(err);
    }
  }

  /**
   * 加密字段
   * @param plainText 明文
   * @param key 包含HMAC的对称密钥
   * @returns `2.Base64(iv)|Base64(ciphertext)|Base64(hmac)` 格式的协议密文。
   * @throws 随机数、Base64 或加密/MAC 计算失败时抛出新 Error。
   */
  static async encryptField(plainText: string, key: string): Promise<string> {
    try {
      // 生成随机IV
      const iv = await CryptoUtil.generateRandom(16);
      // 转换密钥
      const keyBytes = new util.Base64Helper().decodeSync(key);
      const encKey = keyBytes.slice(0, 32);
      const macKey = keyBytes.slice(32);
      // 执行加密
      const cipherText = await CryptoUtil.encryptAESCBC(plainText, iv, encKey);
      // 生成HMAC
      const hmac = await CryptoUtil.generateHMAC(iv, cipherText, macKey);
      // 对IV做base64编码
      const ivStr = new util.Base64Helper().encodeToStringSync(iv);
      // 拼接密文
      return `2.${ivStr}|${cipherText}|${hmac}`;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to encrypt field, error message: ${error.message}`);
      throw new Error(err);
    }
  }

  /**
   * SHA256摘要计算
   * @param plainText 明文
   * @returns 摘要字节直接按 UTF-8 解码后的字符串；空输入返回空字符串。
   * @throws 平台摘要计算失败时传播异常。
   */
  static async doSha256(plainText: string): Promise<string> {
    if (plainText.length == 0) {
      return '';
    }
    let md = cryptoFramework.createMd('SHA256');
    await md.update({ data: new util.TextEncoder().encodeInto(plainText) });
    let mdResult = await md.digest();
    return new util.TextDecoder().decodeToString(mdResult.data);
  }
}
