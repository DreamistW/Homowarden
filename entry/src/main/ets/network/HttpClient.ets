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

/**
 * 创建带统一客户端、设备和语言请求头的 Axios 实例，并记录请求及响应错误。
 * @param baseURL 此实例发送相对路径请求时使用的服务基址。
 * @param config 保留的调用方配置参数；当前实现未将其合并到实例配置中。
 * @returns 配置了 10 秒超时及请求/响应拦截器的 Axios 实例。
 */
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
      Logger.info(`[HTTP] Request ${config.method?.toUpperCase()} ${config.baseURL ||
        baseURL}${config.url}`);
      // Logger.info(`[HTTP] ${config.method?.toUpperCase()} ${config.baseURL ||
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
      // Logger.info(`[HTTP] Response ${response.config.baseURL ||
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

/**
 * 从偏好存储顺序读取服务器类型与自托管地址。
 * @returns 无效服务器类型回退为 US，缺失地址回退为空字符串的配置。
 * @throws 偏好存储读取失败时传播异常。
 */
export async function getServerConfig(): Promise<ServerConfig> {
  let serverConfig: ServerConfig = { serverType: ServerType.US, serverAddress: '' };
  await DataPreferences.getInstance().getPromise<ServerType>(SERVER_TYPE_KEY, ServerType.US).then((data) => {
    // Logger.info(`Server Type preference: ${data}`);
    if (data === ServerType.US || data === ServerType.EU || data === ServerType.SELF_HOSTED) {
      serverConfig.serverType = data;
    }
  })
  await DataPreferences.getInstance().getPromise<string>(SERVER_ADDRESS_KEY, '').then((data) => {
    // Logger.info(`Server Address preference: ${data}`);
    serverConfig.serverAddress = data ?? '';
  })
  return serverConfig;
}

/**
 * 按给定字段顺序生成 application/x-www-form-urlencoded 请求体。
 * @param data 表单值来源；空值按空字符串编码。
 * @param keys 允许写入表单且决定输出顺序的字段列表。
 * @returns 使用 `&` 拼接、值经 URI 编码的表单文本。
 */
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

/**
 * 将 UTF-8 字符串编码为标准 Base64 文本。
 * @param str 待编码的明文字符串。
 * @returns 包含标准 Base64 字母表及填充的文本。
 */
export function encodeStringToBase64(str: string): string {
  const encoder = new util.TextEncoder();
  const data: Uint8Array = encoder.encodeInto(str);
  return new util.Base64Helper().encodeToStringSync(data);
}
