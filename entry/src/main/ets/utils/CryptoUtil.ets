import { taskpool, util } from '@kit.ArkTS';
import { deriveArgon2 } from './Argon2Task';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';
import { KdfParameters } from '../model/Prelogin';

/**
 * 加密工具类
 */
export class CryptoUtil {
  private static argonQueue: Promise<void> = Promise.resolve();
  static async deriveMasterKey(password: string, params: KdfParameters): Promise<string> {
    if (params.salt === undefined) {
      throw new Error('Missing normalized KDF salt');
    }
    if (params.kdf === 0) {
      return CryptoUtil.deriveKeyPBKDF2(password, params.salt, params.kdfIterations, 32);
    }
    if (params.kdf === 1) {
      return CryptoUtil.deriveKeyArgon2id(password, params.salt, params.kdfIterations,
        params.kdfMemory, params.kdfParallelism, 32);
    }
    throw new Error('Unsupported KDF type');
  }

  /**
   * PBKDF2密钥派生
   * @param password 明文密码
   * @param salt 盐
   * @param iterations 迭代次数
   * @param keyLen 派生密钥长度（字节）
   * @returns Base64字符串
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
   * 单次迭代 PBKDF2-SHA256，用于生成服务端登录验证值
   * 单次迭代结果等于 HMAC-SHA256(password, salt || INT32_BE(1))
   */
  static async deriveKeyPBKDF2SingleIteration(password: Uint8Array, salt: string): Promise<string> {
    const saltBytes: Uint8Array = new util.TextEncoder().encodeInto(salt);
    const input: Uint8Array = new Uint8Array(saltBytes.length + 4);
    input.set(saltBytes, 0);
    input.set(new Uint8Array([0, 0, 0, 1]), saltBytes.length);
    const mac = cryptoFramework.createMac('SHA256');
    const keyBlob: cryptoFramework.DataBlob = { data: password };
    const hmacGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
    await mac.init(await hmacGenerator.convertKey(keyBlob));
    await mac.update({ data: input });
    const result: cryptoFramework.DataBlob = await mac.doFinal();
    return new util.Base64Helper().encodeToStringSync(result.data);
  }

  /**
   * HKDF密钥派生
   * @param key 原始密钥
   * @param salt 盐
   * @param info 可选上下文
   * @param keyLen 密钥字节长度
   * @returns Base64字符串
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
   * @param salt 盐
   * @param iterations 迭代次数
   * @param memory 内存（MB）
   * @param parallelism 并行度
   * @param keyLen 派生密钥长度（字节）
   * @returns Base64字符串
   */
  static async deriveKeyArgon2id(password: string, salt: string, iterations: number, memory: number,
    parallelism: number, keyLen: number = 32): Promise<string> {
    const encodedPassword = new util.TextEncoder().encodeInto(password);
    // 原生 API 可能返回外部缓冲区，TaskPool 无法复制；先复制到 VM 管理的数组。
    const passwordBuffer = new Uint8Array(encodedPassword.length);
    passwordBuffer.set(encodedPassword);
    encodedPassword.fill(0);
    const saltBuffer = new util.TextEncoder().encodeInto(salt.trim().toLowerCase());
    // Bitwarden 使用邮箱的 SHA-256 摘要作为 Argon2id 的盐，而不是邮箱原始字节
    const saltDigest = cryptoFramework.createMd('SHA256');
    await saltDigest.update({ data: saltBuffer });
    const saltHash = await saltDigest.digest();
    const taskSalt = new Uint8Array(saltHash.data.length);
    taskSalt.set(saltHash.data);
    saltHash.data.fill(0);

    try {
      // 进程内串行派生，避免多个大内存 KDF 同时运行；绝不降低服务端参数。
      const previous = CryptoUtil.argonQueue;
      const computation = previous.then(async (): Promise<string> => {
        const task = new taskpool.Task(deriveArgon2, passwordBuffer, taskSalt,
          iterations, memory, parallelism, keyLen);
        // 默认会转移 ArrayBuffer；显式复制才能在两端分别清零。
        task.setTransferList([]);
        return await taskpool.execute(task) as string;
      });
      CryptoUtil.argonQueue = computation.then(() => {}, () => {});
      return await computation;
    } catch (error) {
      // TaskPool 序列化异常时会添加 Error 前缀，在边界恢复稳定的业务错误码。
      if ((error as Error).message?.includes('argon2_resources_unavailable')) {
        throw new Error('argon2_resources_unavailable');
      }
      throw new Error('Argon2 computation failed');
    } finally {
      passwordBuffer.fill(0);
      taskSalt.fill(0);
    }
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
   * @returns 解密后的base64字符串
   */
  static async decryptAESCBC(cipherText: string, key: Uint8Array): Promise<string> {
    try {
      const partsOfText = cipherText.substring(2).split('|');
      const cipherBlob: cryptoFramework.DataBlob =
        { data: new util.Base64Helper().decodeSync(partsOfText[1]) };
      const symKey = await CryptoUtil.genSymKeyByData(key);
      const decoder = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      const paramSpec: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: { data: new util.Base64Helper().decodeSync(partsOfText[0]) },
      }
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
   * @returns 比较结果
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
   * @returns 明文字符串
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

  /** 验证主密钥包裹的用户密钥；完整校验 MAC 与解密长度后才允许保存登录状态。 */
  static async decryptUserKey(encryptedUserKey: string, masterKey: string): Promise<string> {
    const masterKeyBytes = new util.Base64Helper().decodeSync(masterKey);
    if (masterKeyBytes.length !== 32 || !encryptedUserKey.startsWith('2.')) {
      throw new Error('Unsupported user key format');
    }
    const encKey = await CryptoUtil.deriveKeyHKDF(masterKeyBytes, 'enc');
    const macKey = await CryptoUtil.deriveKeyHKDF(masterKeyBytes, 'mac');
    const helper = new util.Base64Helper();
    if (!await CryptoUtil.verifyHMAC(encryptedUserKey, helper.decodeSync(macKey))) {
      throw new Error('User key MAC verification failed');
    }
    const userKey = await CryptoUtil.decryptAESCBC(encryptedUserKey, helper.decodeSync(encKey));
    if (helper.decodeSync(userKey).length !== 64) {
      throw new Error('Unsupported user key length');
    }
    return userKey;
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
   * @param iv 初始化向量
   * @param key 对称密钥
   * @returns 加密后的base64字符串
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
   * @param iv 初始化向量
   * @param cipherText base64密文字符串
   * @param macKey 生成MAC的密钥
   * @returns HMAC的base64字符串
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
   * @returns 完整的密文字符串
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
   * @returns SHA256计算结果
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
