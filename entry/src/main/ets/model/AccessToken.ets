export interface AccessTokenRequest {
  grant_type: string;
  username: string;
  password: string;
  scope: string;
  client_id: string;
  deviceType: number;
  deviceIdentifier: string;
  deviceName: string;
  twoFactorToken?: string;
  twoFactorProvider?: number;
  twoFactorRemember?: number;
  newDeviceOtp?: string;
}

export interface AccessTokenResponse {
  access_token: string;
  expires_in: number;
  refresh_token: string;
  PrivateKey?: string;
  Key?: string;
  Kdf?: number;
  KdfIterations?: number | null;
  KdfMemory?: number | null;
  KdfParallelism?: number | null;
  TwoFactorToken?: string;
  UserDecryptionOptions?: UserDecryptionOptions | null;
  AccountKeys?: AccountKeys | null;
  ForcePasswordReset?: boolean;
}

export interface MasterPasswordUnlockKdf {
  KdfType: number;
  Iterations: number;
  Memory?: number | null;
  Parallelism?: number | null;
}

export interface MasterPasswordUnlock {
  Kdf: MasterPasswordUnlockKdf;
  MasterKeyEncryptedUserKey: string;
  Salt?: string | null;
  ContainedKeyId?: string | null;
}

export interface UserDecryptionOptions {
  HasMasterPassword?: boolean;
  MasterPasswordUnlock?: MasterPasswordUnlock | null;
}

export interface AccountKeys {
  publicKeyEncryptionKeyPair?: PublicKeyEncryptionKeyPair | null;
}

export interface PublicKeyEncryptionKeyPair {
  wrappedPrivateKey?: string | null;
  publicKey?: string | null;
}

export enum TwoFactorProvider {
  AUTHENTICATOR_APP = 0,
  EMAIL = 1,
  REMEMBER = 5,
  WEB_AUTHN = 7
}

export type TwoFactorProviderData = Record<string, Object | string | number | boolean | null | undefined>;
