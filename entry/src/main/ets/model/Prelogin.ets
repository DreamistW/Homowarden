export interface PreloginRequest {
  email: string;
}

export interface PreloginResponse {
  kdf: number;
  kdfIterations: number;
  kdfMemory: number;
  kdfParallelism: number;
}