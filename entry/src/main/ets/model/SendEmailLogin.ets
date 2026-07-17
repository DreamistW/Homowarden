/** 发送邮箱 2FA 验证码的请求，字段名遵循服务端 JSON 协议大小写。 */
export interface SendEmailLoginRequest {
  DeviceIdentifier: string;
  Email: string;
  /** 由主密钥与主密码二次派生的登录哈希，不是主密码明文。 */
  MasterPasswordHash: string;
  SsoEmail2FaSessionToken?: string;
}

/** 重发新设备 OTP 的请求。 */
export interface ResendNewDeviceOtpRequest {
  Email: string;
  MasterPasswordHash: string;
}
