import { argon2Hash, HashOption } from '@huozhiniao/argon2';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';

/**
 * 加密工具类
 */
export class Crypto {
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
      return new util.Base64Helper().encodeToStringSync(secret.data, util.Type.BASIC);
    })
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
        { data: new util.Base64Helper().decodeSync(partsOfText[1], util.Type.BASIC) };
      const symKey = await Crypto.genSymKeyByData(key);
      Logger.debug(`cipherText length: ${cipherBlob.data.length}`);
      Logger.debug(`key length: ${key.length}`);
      const decoder = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      const paramSpec: cryptoFramework.IvParamsSpec = {
        algName: 'IvParamsSpec',
        iv: { data: new util.Base64Helper().decodeSync(partsOfText[0], util.Type.BASIC) },
      }
      Logger.debug(`iv length: ${paramSpec.iv.data.length}`);
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
    let mac = cryptoFramework.createMac('SHA256');
    await mac.init(await Crypto.genSymKeyByData(macKey));
    await mac.update({ data: macData });
    let macResult = await mac.doFinal();
    const macResultStr = new util.Base64Helper().encodeToStringSync(macResult.data, util.Type.BASIC);
    if (partsOfText[2] == macResultStr) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * 解密字段
   * @param cipherText 完整的密文
   * @param symKey 对称密钥
   * @returns 明文字符串
   */
  static async decryptField(cipherText: string, symKey: string) {
    if(!cipherText || cipherText.length == 0) return '';
    const keyBytes = new util.Base64Helper().decodeSync(symKey, util.Type.BASIC);
    // MAC验证
    const macKeyBytes = keyBytes.slice(32);
    const macResult = await Crypto.verifyHMAC(cipherText, macKeyBytes);
    if (macResult) {
      const plainText = await Crypto.decryptAESCBC(cipherText, keyBytes.slice(0, 32));
      return Crypto.base64DecodeToString(plainText);
    } else {
      throw new Error(`MAC verification failed`);
    }
  }

  // Base64字符串解码
  static base64DecodeToString(base64: string): string {
    const bytes = new util.Base64Helper().decodeSync(base64);
    const str = new util.TextDecoder().decodeToString(bytes);
    return str;
  }
}
