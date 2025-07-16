import axios, { AxiosRequestConfig, InternalAxiosRequestConfig, AxiosResponse, AxiosError } from '@ohos/axios';
import { Logger } from '@nzy/logger';

export function createHttpClient(baseURL: string, config?: AxiosRequestConfig) {
  const instance = axios.create({
    baseURL,
    timeout: 10000,
    headers: {
      "Content-Type": "application/json"
    }
  });

  // 请求拦截器
  instance.interceptors.request.use(
    (config: InternalAxiosRequestConfig) => {
      Logger.debug(`[HTTP] ${config.method?.toUpperCase()} ${config.baseURL || baseURL}${config.url}\nRequest: ${JSON.stringify(config.data)}`);
      return config;
    },
    (error: AxiosError) => {
      Logger.error(`[HTTP] Request Error: ${error.message}`);
      return Promise.reject(error);
    }
  );

  // 响应拦截器
  instance.interceptors.response.use(
    (response: AxiosResponse) => {
      Logger.debug(`[HTTP] Response ${response.config.baseURL || baseURL}${response.config.url}\nResponse: ${JSON.stringify(response.data)}`);
      return response;
    },
    (error: AxiosError) => {
      Logger.error(`[HTTP] Response Error: ${error.message}\n${JSON.stringify(error.response?.data)}`);
      return Promise.reject(error);
    }
  );

  return instance;
}