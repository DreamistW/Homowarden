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
  Kdf: number;
  KdfIterations?: number;
  KdfMemory?: number;
  KdfParallelism?: number;
  TwoFactorToken?: string;
}

export enum TwoFactorProvider {
  AUTHENTICATOR_APP = 0,
  EMAIL = 1,
  REMEMBER = 5,
  WEB_AUTHN = 7
}

export type TwoFactorProviderData = Record<string, Object | string | number | boolean | null | undefined>;
