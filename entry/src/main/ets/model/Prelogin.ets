/** 预登录请求；邮箱应在调用前 trim、转小写。 */
export interface PreloginRequest {
  email: string;
}

/** 服务端为账号配置的主密钥 KDF 参数。 */
export interface PreloginResponse {
  /** 0 表示 PBKDF2，1 表示 Argon2id。 */
  kdf: number;
  kdfIterations: number;
  kdfMemory: number;
  kdfParallelism: number;
}
