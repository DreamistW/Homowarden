// HTTP客户端，使用Axios实现

import axios, { AxiosError, AxiosRequestConfig, AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios';
import { Logger } from '@nzy/logger';
import {
  Header_Client_Name,
  Header_Client_Version,
  SERVER_ADDRESS_KEY,
  SERVER_TYPE_KEY,
  ServerType
} from '../utils/Constants';
import { DeviceUtil } from '../utils/DeviceUtil';
import { DataPreferences } from '@abner/datastore';
import { util } from '@kit.ArkTS';
import { ServerConfig } from '../model/ServerConfig';

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
      config.headers['Accept-Language'] = "zh-CN,zh;q=0.9";
      // config.headers['accept'] = 'application/json';
      // config.headers['origin'] = config.baseURL
      Logger.debug(`[HTTP] Request ${config.method?.toUpperCase()} ${config.baseURL ||
        baseURL}${config.url}`);
      // Logger.debug(`[HTTP] ${config.method?.toUpperCase()} ${config.baseURL ||
      //   baseURL}${config.url}\nHeader:${JSON.stringify(config.headers)}\nRequest: ${JSON.stringify(config.data)}`);
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
      // Logger.debug(`[HTTP] Response ${response.config.baseURL ||
      //   baseURL}${response.config.url}\nResponse: ${JSON.stringify(response.data)}`);
      return response;
    },
    (error: AxiosError) => {
      Logger.error(`[HTTP] Response Error: ${error.message}\n${JSON.stringify(error.response?.data)}`);
      return Promise.reject(error);
    }
  );

  return instance;
}

// 从配置文件中读取服务器地址
export async function getServerConfig(): Promise<ServerConfig> {
  let serverConfig: ServerConfig = { serverType: ServerType.US, serverAddress: '' };
  await DataPreferences.getInstance().getPromise<ServerType>(SERVER_TYPE_KEY).then((data) => {
    // Logger.debug(`Server Type preference: ${data}`);
    serverConfig.serverType = data;
  })
  await DataPreferences.getInstance().getPromise<string>(SERVER_ADDRESS_KEY).then((data) => {
    // Logger.debug(`Server Address preference: ${data}`);
    serverConfig.serverAddress = data;
  })
  return serverConfig;
}

// 处理表单内容
export function toFormUrlEncoded<T extends object>(data: T, keys: (keyof T)[]): string {
  return keys
    .map(key => {
      const keyStr = String(key);
      const value = (data[key] as string) ?? '';
      // 对值进行表单编码
      return keyStr + '=' + encodeURIComponent(value);
    })
    .join('&');
}

// 表单值编码函数，排除token中的符号不做处理
function encodeFormValue(value: string): string {
  return value.replace(/[^A-Za-z0-9\-._~=]/g, (char) => {
    switch (char) {
      case ' ':
        return '+'; // 空格编码为+
      case '&':
        return '%26'; // &编码为%26
      case '+':
        return '%2B'; // +编码为%2B
      default:
        return encodeURIComponent(char);
    }
  });
}

export function encodeStringToBase64(str: string): string {
  const encoder = new util.TextEncoder();
  const data: Uint8Array = encoder.encodeInto(str);
  return new util.Base64Helper().encodeToStringSync(data);
}