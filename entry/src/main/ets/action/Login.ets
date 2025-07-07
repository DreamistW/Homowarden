import { Logger } from '@nzy/logger';
import axios, { AxiosError, AxiosResponse } from '@ohos/axios'
import { preLoginModel } from '../model/Login';

axios.defaults.connectTimeout = 5000;
axios.defaults.readTimeout = 5000;
axios.defaults.maxContentLength = -1;

export async function preLogin(address: string, email: string): Promise<preLoginModel> {
  const targetUrl = `${address}/api/accounts/prelogin`;
  Logger.debug(`POST ${targetUrl}`);
  return axios.post<preLoginModel>(targetUrl, `{"email": "${email}"}`,
    { headers: { 'Content-Type': 'application/json', } })
    .then((response: AxiosResponse<preLoginModel>) => {
      return response.data;
    })
    .catch((error: AxiosError) => {
      Logger.error(`preLogin failed: ${error.message}`);
      return Promise.reject(error);
    })
}