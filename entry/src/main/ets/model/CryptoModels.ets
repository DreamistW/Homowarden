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