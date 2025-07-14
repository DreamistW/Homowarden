import axios, { AxiosRequestConfig } from '@ohos/axios';

export function createHttpClient(baseURL: string, config?: AxiosRequestConfig) {
  return axios.create({
    baseURL,
    timeout: 10000,
    headers: {
      "Content-Type": "application/json"
    }
  });
}