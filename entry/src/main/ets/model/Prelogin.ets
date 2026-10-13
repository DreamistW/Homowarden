export interface PreloginRequest {
  email: string;
}

export interface PreloginResponse {
  kdf?: number | null;
  kdfIterations?: number | null;
  kdfMemory?: number | null;
  kdfParallelism?: number | null;
  kdfSettings?: KdfSettings | null;
  salt?: string | null;
}

export interface KdfSettings {
  kdfType: number;
  iterations: number;
  memory?: number | null;
  parallelism?: number | null;
}

/** 经过校验的派生参数，也兼容升级前持久化的邮箱盐记录。 */
export interface KdfParameters {
  kdf: number;
  kdfIterations: number;
  kdfMemory: number;
  kdfParallelism: number;
  salt?: string;
}
