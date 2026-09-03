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
import { LocaleUtil } from '../localization/LocaleUtil';
import { LogSanitizer } from '../utils/LogSanitizer';

const DIAGNOSTIC_AUTH_PATHS: Array<string> = [
  '/accounts/prelogin',
  '/connect/token',
  '/two-factor/send-email-login',
  '/accounts/resend-new-device-otp'
];
const MAX_DIAGNOSTIC_BODY_LENGTH = 8 * 1024;

/**
 * 创建带客户端标识、语言协商和统一错误日志的 HTTP 客户端
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
      config.headers['Accept-Language'] = LocaleUtil.getAcceptLanguage();
      // 正常请求日志不记录可能包含凭据的请求头和请求体
      const requestPath = (config.url ?? '').split('?')[0];
      const diagnosticBody = formatDiagnosticBody(requestPath, config.data);
      Logger.info(`[HTTP] Request ${config.method?.toUpperCase()} ${requestPath}${diagnosticBody}`);
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
      const responsePath = (response.config.url ?? '').split('?')[0];
      const diagnosticBody = formatDiagnosticBody(responsePath, response.data);
      Logger.info(`[HTTP] Response ${response.status} ${responsePath}${diagnosticBody}`);
      return response;
    },
    (error: AxiosError) => {
      const responsePath = (error.config?.url ?? '').split('?')[0];
      const responseData = error.response?.data as Object | string | undefined;
      const diagnosticBody = formatDiagnosticBody(responsePath, responseData);
      Logger.error(`[HTTP] Response Error: status=${error.response?.status ?? 0}, path=${responsePath}, ` +
        `message=${error.message}${diagnosticBody}`);
      return Promise.reject(error);
    }
  );

  return instance;
}

/** 认证接口使用白名单记录负载，所有内容在进入 Logger 前再次脱敏并限制长度。 */
function formatDiagnosticBody(path: string, body: Object | string | undefined): string {
  if (!DIAGNOSTIC_AUTH_PATHS.includes(path) || body === undefined) {
    return '';
  }
  try {
    const serialized = typeof body === 'string' ? body : JSON.stringify(body);
    const sanitized = LogSanitizer.sanitize(serialized);
    const limited = sanitized.length > MAX_DIAGNOSTIC_BODY_LENGTH ?
      `${sanitized.substring(0, MAX_DIAGNOSTIC_BODY_LENGTH)}...[TRUNCATED]` : sanitized;
    return ` payload=${limited}`;
  } catch (_) {
    return ' payload=[UNSERIALIZABLE]';
  }
}

// 从配置文件中读取服务器地址
export async function getServerConfig(): Promise<ServerConfig> {
  let serverConfig: ServerConfig = { serverType: ServerType.US, serverAddress: '' };
  await DataPreferences.getInstance().getPromise<ServerType>(SERVER_TYPE_KEY, ServerType.US).then((data) => {
    if (data === ServerType.US || data === ServerType.EU || data === ServerType.SELF_HOSTED) {
      serverConfig.serverType = data;
    }
  })
  await DataPreferences.getInstance().getPromise<string>(SERVER_ADDRESS_KEY, '').then((data) => {
    serverConfig.serverAddress = data ?? '';
  })
  return serverConfig;
}

/**
 * 仅序列化白名单字段，避免把请求模型中的非协议字段一并发送
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

export function encodeStringToBase64(str: string): string {
  const encoder = new util.TextEncoder();
  const data: Uint8Array = encoder.encodeInto(str);
  return new util.Base64Helper().encodeToStringSync(data);
}
