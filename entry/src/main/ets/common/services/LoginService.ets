import { Logger } from '@nzy/logger';
import axios, { AxiosError, AxiosResponse } from '@ohos/axios'
import { preloginResponse } from '../models/Response/PreloginResponse';

axios.defaults.connectTimeout = 5000;
axios.defaults.readTimeout = 5000;
axios.defaults.maxContentLength = -1;

export async function preLogin(address: string, email: string): Promise<preloginResponse> {
  const targetUrl = `https://${address}/api/accounts/prelogin`;
  Logger.debug(`POST ${targetUrl}`);
  return axios.post<preloginResponse>(targetUrl, `{"email": "${email}"}`,
    { headers: { 'Content-Type': 'application/json', } })
    .then((response: AxiosResponse<preloginResponse>) => {
      return response.data;
    })
    .catch((error: AxiosError) => {
      Logger.error(`preLogin failed: ${error.message}`);
      return Promise.reject(error);
    })
}