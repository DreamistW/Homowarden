// HTTP客户端，使用Axios实现

import axios, { AxiosRequestConfig, InternalAxiosRequestConfig, AxiosResponse, AxiosError } from '@ohos/axios';
import { Logger } from '@nzy/logger';
import { Header_Client_Name, Header_Client_Version } from '../utils/Constants';
import { DeviceUtil } from '../utils/DeviceUtil';

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
    async (config: InternalAxiosRequestConfig) => {
      config.headers['bitwarden-client-name'] = Header_Client_Name;
      config.headers['bitwarden-client-version'] = Header_Client_Version;
      config.headers['device-type'] = DeviceUtil.getDeviceType();
      config.headers['device-identifier'] = await DeviceUtil.getOrGenerateDeviceIdentifier();
      config.headers['Accept-Language'] = "zh-CN,zh;q=0.9";
      config.headers['Origin'] = config.baseURL
      Logger.debug(`[HTTP] ${config.method?.toUpperCase()} ${config.baseURL || baseURL}${config.url}\nHeader:${JSON.stringify(config.headers)}\nRequest: ${JSON.stringify(config.data)}`);
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