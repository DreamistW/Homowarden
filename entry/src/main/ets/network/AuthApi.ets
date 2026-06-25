import { createHttpClient, encodeStringToBase64, toFormUrlEncoded } from './HttpClient';
import { AxiosResponse } from '@ohos/axios';
import { Logger } from '@nzy/logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreloginRequest, PreloginResponse } from '../model/Prelogin';
import { AccessTokenRequest, AccessTokenResponse } from '../model/AccessToken';
import { RefreshTokenRequest, RefreshTokenResponse } from '../model/RefreshToken';
import { ResendNewDeviceOtpRequest, SendEmailLoginRequest } from '../model/SendEmailLogin';
import { getServerEndpoints } from './ServerEndpointResolver';


// 预登录接口
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


// 登录接口
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

// 更新token接口
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
    } else {
      return false;
    }
  }).catch((error: BusinessError) => {
    Logger.error("Failed to send email request, error message: " + error.message);
    return false;
  })
}

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
    return response.status === 200;
  }).catch((error: BusinessError) => {
    Logger.error("Failed to resend new device OTP, error message: " + error.message);
    return false;
  })
}
