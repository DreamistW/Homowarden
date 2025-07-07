export interface preLoginModel {
  kdf: number;
  kdfIterations: number;
  kdfMemory: number;
  kdfParallelism: number;
}

export enum serverType{
  NORMAL,
  EU,
  CUSTOM
}