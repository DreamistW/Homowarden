/**
 * Argon2派生结果类型（@huozhiniao/argon2）
 */
export interface Argon2Result {
  hash: string; // Base64 编码的摘要
  encoded: string;
}

export interface EncryptedStringResult {
  encrypted: string;
  iv: string;
}
