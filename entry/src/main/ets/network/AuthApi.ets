import { createHttpClient, encodeStringToBase64, getServerConfig, toFormUrlEncoded } from './HttpClient';
import { AxiosResponse } from '@ohos/axios';
import { SERVER_BASE_URL_EU, SERVER_BASE_URL_US, ServerType } from '../utils/Constants';
import { Logger } from '@nzy/logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreloginRequest, PreloginResponse } from '../model/Prelogin';
import { AccessTokenRequest, AccessTokenResponse } from '../model/AccessToken';
import { RefreshTokenRequest, RefreshTokenResponse } from '../model/RefreshToken';
import { SendEmailLoginRequest } from '../model/SendEmailLogin';


// 预登录接口
export async function prelogin(request: PreloginRequest): Promise<PreloginResponse> {
  const serverConfig = await getServerConfig();
  // 需要根据不同服务器类型拼接URL
  // 例如官方服务器：https://identity.bitwarden.com/accounts/prelogin
  // 自定义服务器：https://your.domain.com/api/accounts/prelogin
  let baseURL = '';
  if (serverConfig.serverType == ServerType.US) {
    baseURL = `https://vault.${SERVER_BASE_URL_US}/identity`;
  } else if (serverConfig.serverType == ServerType.EU) {
    baseURL = `https://vault.${SERVER_BASE_URL_EU}/identity`;
  } else {
    baseURL = `https://${serverConfig.serverAddress}/api`;
  }
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
  const serverConfig = await getServerConfig();
  let baseURL = '';
  if (serverConfig.serverType == ServerType.US) {
    baseURL = `https://vault.${SERVER_BASE_URL_US}`;
  } else if (serverConfig.serverType == ServerType.EU) {
    baseURL = `https://vault.${SERVER_BASE_URL_EU}`;
  } else {
    baseURL = `https://${serverConfig.serverAddress}`;
  }
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

  return client.post('/identity/connect/token', formBody,
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'auth-email': encodeStringToBase64(request.username),
        'origin': baseURL
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
  const serverConfig = await getServerConfig();
  let baseURL = '';
  if (serverConfig.serverType == ServerType.US) {
    baseURL = `https://vault.${SERVER_BASE_URL_US}`;
  } else if (serverConfig.serverType == ServerType.EU) {
    baseURL = `https://vault.${SERVER_BASE_URL_EU}`;
  } else {
    baseURL = `https://${serverConfig.serverAddress}`;
  }
  const client = createHttpClient(baseURL);

  let fields = [
    'grant_type',
    'refresh_token',
    'client_id'
  ] as (keyof RefreshTokenRequest)[];

  const formBody = toFormUrlEncoded(request, fields);

  return client.post('/identity/connect/token', formBody,
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
  const serverConfig = await getServerConfig();
  let baseURL = '';
  if (serverConfig.serverType == ServerType.US) {
    baseURL = `https://vault.${SERVER_BASE_URL_US}`;
  } else if (serverConfig.serverType == ServerType.EU) {
    baseURL = `https://vault.${SERVER_BASE_URL_EU}`;
  } else {
    baseURL = `https://${serverConfig.serverAddress}`;
  }
  const client = createHttpClient(baseURL);
  return client.post('/api/two-factor/send-email-login', request, {
    headers: {
      'origin': baseURL,
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