export interface SendEmailLoginRequest {
  DeviceIdentifier: string;
  Email: string;
  MasterPasswordHash: string;
  SsoEmail2FaSessionToken?: string;
}

export interface ResendNewDeviceOtpRequest {
  Email: string;
  MasterPasswordHash: string;
}
