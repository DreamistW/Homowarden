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
  PrivateKey: string;
  Key: string;
  Kdf: number;
  KdfIterations: number;
  KdfMemory: number;
  KdfParallelism: number;
  TwoFactorToken: string;
} 