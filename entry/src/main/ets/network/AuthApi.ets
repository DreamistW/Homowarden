import { createHttpClient, encodeStringToBase64, toFormUrlEncoded } from './HttpClient';
import { AxiosResponse } from '@ohos/axios';
import { Logger } from '@nzy/logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreloginRequest, PreloginResponse } from '../model/Prelogin';
import { AccessTokenRequest, AccessTokenResponse } from '../model/AccessToken';
import { RefreshTokenRequest, RefreshTokenResponse } from '../model/RefreshToken';
import { ResendNewDeviceOtpRequest, SendEmailLoginRequest } from '../model/SendEmailLogin';
import { getServerEndpoints } from './ServerEndpointResolver';


/**
 * 查询账号使用的 KDF 参数，为本地主密码派生提供依据。
 * @param request 包含规范化登录邮箱的预登录请求。
 * @returns 服务端返回的 KDF 类型、迭代次数及可选参数。
 * @throws 端点解析失败或 HTTP 请求失败时原样传播异常。
 */
export async function prelogin(request: PreloginRequest): Promise<PreloginResponse> {
  const endpoints = await getServerEndpoints();
  const baseURL = endpoints.identityBaseUrl;
  const client = createHttpClient(baseURL);
  return client.post(
    '/accounts/prelogin',
    request,
    {
      headers: {
        'Content-Type': 'application/json',
      }
    }
  ).then((response: AxiosResponse<PreloginResponse>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error("failed to prelogin, error message: " + error.message);
    return Promise.reject(error);
  })
}


/**
 * 以表单方式提交密码授权，并按请求内容附加 2FA 或新设备 OTP 字段。
 * @param request 用户名、派生后的登录密码、设备信息及可选二次认证数据。
 * @returns 身份服务返回的访问令牌、刷新令牌及加密相关资料。
 * @throws 端点解析、Base64 编码或 HTTP 请求失败时传播异常。
 */
export async function accessToken(request: AccessTokenRequest): Promise<AccessTokenResponse> {
  const endpoints = await getServerEndpoints();
  const baseURL = endpoints.identityBaseUrl;
  const client = createHttpClient(baseURL);

  let fields = [
    'scope',
    'client_id',
    'deviceType',
    'deviceIdentifier',
    'deviceName',
    'grant_type',
    'username',
    'password',
  ] as (keyof AccessTokenRequest)[];

  if (request.twoFactorToken) {
    fields.push('twoFactorToken' as keyof AccessTokenRequest);
    fields.push('twoFactorProvider' as keyof AccessTokenRequest);
    fields.push('twoFactorRemember' as keyof AccessTokenRequest);
  }

  if (request.newDeviceOtp) {
    fields.push('newDeviceOtp' as keyof AccessTokenRequest);
  }

  const formBody = toFormUrlEncoded(request, fields);

  return client.post('/connect/token', formBody,
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'auth-email': encodeStringToBase64(request.username),
        'origin': endpoints.vaultBaseUrl
      }
    })
    .then((response: AxiosResponse<AccessTokenResponse>) => {
      return response.data;
    })
    .catch((error: BusinessError) => {
      Logger.error("Failed to get token, error message: " + error.message);
      return Promise.reject(error);
    })
}

/**
 * 使用刷新令牌换取新的访问令牌。
 * @param request 刷新授权所需的客户端标识、授权类型和刷新令牌。
 * @returns 身份服务返回的新令牌及有效期。
 * @throws 端点解析或 HTTP 请求失败时传播异常。
 */
export async function refreshToken(request: RefreshTokenRequest): Promise<RefreshTokenResponse> {
  const endpoints = await getServerEndpoints();
  const baseURL = endpoints.identityBaseUrl;
  const client = createHttpClient(baseURL);

  let fields = [
    'grant_type',
    'refresh_token',
    'client_id'
  ] as (keyof RefreshTokenRequest)[];

  const formBody = toFormUrlEncoded(request, fields);

  return client.post('/connect/token', formBody,
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      }
    })
    .then((response: AxiosResponse<RefreshTokenResponse>) => {
      return response.data;
    })
    .catch((error: BusinessError) => {
      Logger.error("Failed to refresh token, error message: " + error.message);
      return Promise.reject(error);
    })
}

/**
 * 请求服务端发送邮箱二次验证码。
 * @returns 仅 HTTP 200 返回 `true`；请求异常会记录日志并转换为 `false`。
 */
export async function sendEmailLogin(request: SendEmailLoginRequest): Promise<boolean> {
  const endpoints = await getServerEndpoints();
  const baseURL = endpoints.apiBaseUrl;
  const client = createHttpClient(baseURL);
  return client.post('/two-factor/send-email-login', request, {
    headers: {
      'origin': endpoints.vaultBaseUrl,
      'Content-Type': 'application/json',
    }
  }).then((response: AxiosResponse) => {
    if (response.status === 200) {
      return true;
    }
    throw new Error(`发送验证码失败，HTTP ${response.status}`);
  }).catch((error: BusinessError) => {
    Logger.error("Failed to send email request, error message: " + error.message);
    return Promise.reject(error);
  })
}

/**
 * 重新发送新设备确认验证码。
 * @returns 仅 HTTP 200 返回 `true`；请求异常会记录日志并转换为 `false`。
 */
export async function resendNewDeviceOtp(request: ResendNewDeviceOtpRequest): Promise<boolean> {
  const endpoints = await getServerEndpoints();
  const baseURL = endpoints.apiBaseUrl;
  const client = createHttpClient(baseURL);
  return client.post('/accounts/resend-new-device-otp', request, {
    headers: {
      'origin': endpoints.vaultBaseUrl,
      'Content-Type': 'application/json',
    }
  }).then((response: AxiosResponse) => {
    if (response.status === 200) {
      return true;
    }
    throw new Error(`发送验证码失败，HTTP ${response.status}`);
  }).catch((error: BusinessError) => {
    Logger.error("Failed to resend new device OTP, error message: " + error.message);
    return Promise.reject(error);
  })
}
