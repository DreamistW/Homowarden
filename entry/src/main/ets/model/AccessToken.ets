/** 身份服务密码授权表单；可选认证字段按当前挑战分支提交。 */
export interface AccessTokenRequest {
  grant_type: string;
  username: string;
  /** 由主密钥和主密码二次派生的 Base64 登录哈希，不是用户主密码明文。 */
  password: string;
  scope: string;
  client_id: string;
  deviceType: number;
  deviceIdentifier: string;
  deviceName: string;
  /** 2FA token：验证码、记住设备令牌或序列化的 FIDO2 认证响应。 */
  twoFactorToken?: string;
  twoFactorProvider?: number;
  twoFactorRemember?: number;
  newDeviceOtp?: string;
}

/** 登录成功后返回的会话令牌和解密资料。 */
export interface AccessTokenResponse {
  access_token: string;
  /** 访问令牌有效秒数。 */
  expires_in: number;
  refresh_token: string;
  /** 账户私钥密文，可能因协议或账号状态缺失。 */
  PrivateKey?: string;
  /** 受主密钥保护的用户对称密钥密文。 */
  Key?: string;
  Kdf: number;
  KdfIterations?: number;
  KdfMemory?: number;
  KdfParallelism?: number;
  /** 选择“记住我”后由服务端签发的后续 2FA token。 */
  TwoFactorToken?: string;
}

/** 身份服务协议定义的二次认证提供方编号，数值不可随意调整。 */
export enum TwoFactorProvider {
  AUTHENTICATOR_APP = 0,
  EMAIL = 1,
  REMEMBER = 5,
  WEB_AUTHN = 7
}

/** 服务端按提供方返回的动态 FIDO2/2FA 参数记录。 */
export type TwoFactorProviderData = Record<string, Object | string | number | boolean | null | undefined>;
