/**
 * Argon2派生结果类型（@huozhiniao/argon2）
 */
export interface Argon2Result {
  hash: string; // Base64 原始派生结果
  encoded: string;
}

/** AES 加密中间结果：密文与 IV 分别为 Base64 文本。 */
export interface EncryptedStringResult {
  encrypted: string;
  iv: string;
}
