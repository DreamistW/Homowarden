import { createHttpClient } from './HttpClient.ets';
import { PreloginRequest } from '../model/PreloginRequest.ets';
import { PreloginResponse } from '../model/PreloginResponse.ets';
import { AccessTokenRequest } from '../model/AccessTokenRequest.ets';
import { AccessTokenResponse } from '../model/AccessTokenResponse.ets';
import { AxiosResponse } from '@ohos/axios';
import { DataPreferences } from '@abner/datastore';
import {
  ServerType,
  SERVER_TYPE_KEY,
  SERVER_ADDRESS_KEY,
  SERVER_BASE_URL_US,
  SERVER_BASE_URL_EU
} from '../utils/Constants.ets';
import { Logger } from '@nzy/logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

async function getServerConfig(): Promise<ServerConfig> {
  let serverConfig: ServerConfig = { serverType: ServerType.US, serverAddress: '' };
  await DataPreferences.getInstance().getPromise<ServerType>(SERVER_TYPE_KEY).then((data) => {
    Logger.debug(`Server Type preference: ${data}`);
    serverConfig.serverType = data;
  })
  await DataPreferences.getInstance().getPromise<string>(SERVER_ADDRESS_KEY).then((data) => {
    Logger.debug(`Server Address preference: ${data}`);
    serverConfig.serverAddress = data;
  })
  return serverConfig;
}

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
    Logger.error("Prelogin failed, error message: " + error.message);
    return Promise.reject(error);
  })
}

// 处理表单内容
function toFormUrlEncoded<T extends object>(data: T, keys: (keyof T)[]): string {
  return keys
    .map(key => encodeURIComponent(String(key)) + '=' + encodeURIComponent((data[key] as string) ?? ''))
    .join('&');
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
    'grant_type',
    'username',
    'password',
    'scope',
    'client_id',
    'deviceType',
    'deviceIdentifier',
    'deviceName'
  ] as (keyof AccessTokenRequest)[];

  if (request.twoFactorToken) {
    fields.push('twoFactorToken' as keyof AccessTokenRequest);
    fields.push('twoFactorProvider' as keyof AccessTokenRequest);
    fields.push('twoFactorRemember' as keyof AccessTokenRequest);
  }

  const formBody = toFormUrlEncoded(request, fields);

  return client.post('/identity/connect/token', formBody,
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'auth-email': encodeStringToBase64(request.username),
      }
    })
    .then((response: AxiosResponse<AccessTokenResponse>) => {
      return response.data;
    })
    .catch((error: BusinessError) => {
      Logger.error("Get token failed, error message: " + error.message);
      return Promise.reject(error);
    })
}

export interface ServerConfig {
  serverType: ServerType,
  serverAddress: string
}

function encodeStringToBase64(str: string): string {
  const encoder = new util.TextEncoder();
  const data: Uint8Array = encoder.encodeInto(str);
  return new util.Base64Helper().encodeToStringSync(data, util.Type.BASIC);
}