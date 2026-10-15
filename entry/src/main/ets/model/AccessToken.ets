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
  forcePasswordReset?: boolean;
  userDecryptionOptions?: UserDecryptionOptions | null;
  accountKeys?: AccountKeys | null;
  key?: string;
  privateKey?: string;
}

export interface MasterPasswordUnlockKdf {
  KdfType?: number;
  Iterations?: number;
  Memory?: number | null;
  Parallelism?: number | null;
  kdfType?: number;
  iterations?: number;
  memory?: number | null;
  parallelism?: number | null;
}

export interface MasterPasswordUnlock {
  Kdf?: MasterPasswordUnlockKdf;
  kdf?: MasterPasswordUnlockKdf;
  MasterKeyEncryptedUserKey?: string;
  masterKeyEncryptedUserKey?: string;
  MasterKeyWrappedUserKey?: string;
  masterKeyWrappedUserKey?: string;
  Salt?: string | null;
  salt?: string | null;
  ContainedKeyId?: string | null;
}

export interface UserDecryptionOptions {
  HasMasterPassword?: boolean;
  MasterPasswordUnlock?: MasterPasswordUnlock | null;
  hasMasterPassword?: boolean;
  masterPasswordUnlock?: MasterPasswordUnlock | null;
}

export interface AccountKeys {
  publicKeyEncryptionKeyPair?: PublicKeyEncryptionKeyPair | null;
  PublicKeyEncryptionKeyPair?: PublicKeyEncryptionKeyPair | null;
}

export interface PublicKeyEncryptionKeyPair {
  wrappedPrivateKey?: string | null;
  WrappedPrivateKey?: string | null;
  publicKey?: string | null;
}

export enum TwoFactorProvider {
  AUTHENTICATOR_APP = 0,
  EMAIL = 1,
  REMEMBER = 5,
  WEB_AUTHN = 7
}

export type TwoFactorProviderData = Record<string, Object | string | number | boolean | null | undefined>;
