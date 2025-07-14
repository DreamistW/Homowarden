import { createHttpClient } from './HttpClient.ets';
import { PreloginRequest } from '../model/PreloginRequest.ets';
import { PreloginResponse } from '../model/PreloginResponse.ets';
import { AccessTokenRequest } from '../model/AccessTokenRequest.ets';
import { AccessTokenResponse } from '../model/AccessTokenResponse.ets';
import { AxiosResponse } from '@ohos/axios';

// 预登录接口
export async function prelogin(request: PreloginRequest, baseURL: string): Promise<PreloginResponse> {
  const client = createHttpClient(baseURL);
  const response: AxiosResponse<PreloginResponse, object> = await client.post(
    '/accounts/prelogin',
    request,
    { headers: { 'Content-Type': 'application/json' } }
  );
  return response.data;
}

function toFormUrlEncoded<T extends object>(data: T, keys: (keyof T)[]): string {
  return keys
    .map(key => encodeURIComponent(String(key)) + '=' + encodeURIComponent((data[key] as string) ?? ''))
    .join('&');
}

// 登录接口
export async function accessToken(request: AccessTokenRequest, baseURL: string): Promise<AccessTokenResponse> {
  const client = createHttpClient(baseURL);
  const formBody = toFormUrlEncoded(request, [
    'grant_type',
    'username',
    'password',
    'scope',
    'client_id'
  ]);
  const response: AxiosResponse<AccessTokenResponse, object> = await client.post(
    '/connect/token',
    formBody,
    { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
  );
  return response.data;
}