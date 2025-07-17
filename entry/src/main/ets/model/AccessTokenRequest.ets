export interface AccessTokenRequest {
  grant_type: string;
  username: string;
  password: string;
  scope: string;
  client_id: string;
  deviceType: number;
  deviceIdentifier: string;
  deviceName: string;
  two_factor_token?: string;
  two_factor_provider?: number;
  twoFactorRemember?: number;
} 