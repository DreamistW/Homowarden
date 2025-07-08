import { argon2Hash, HashOption } from '@huozhiniao/argon2';
import { CryptoJS } from '@ohos/crypto-js';
import { preloginResponse } from '../models/Response/PreloginResponse'
import { buffer } from '@kit.ArkTS';
import { Logger } from '@nzy/logger'

export async function deriveMasterPasswordHash(password: string, email: string, preLogin: preloginResponse): Promise<string> {
  const pwdBuffer = buffer.from(password).buffer;
  const saltBuffer = buffer.from(email).buffer;
  const kdf = preLogin.kdf;
  const kdfIterations = preLogin.kdfIterations;

  let option = new HashOption();
  option.memoryCost = 65536;
  option.argon2Type = 2;
  option.timeCost = kdfIterations;
  option.parallelism = 1;
  option.hashLength = 32;

  let output = argon2Hash(pwdBuffer, saltBuffer, option);
  Logger.debug(`output hash: ${output}`);
  let encryptedHash = CryptoJS.enc.Base64.stringify(CryptoJS.HmacSHA256(output.encoded, email.toLowerCase()));
  Logger.debug(`encrypted hash: ${encryptedHash}`);
  return encryptedHash;
}