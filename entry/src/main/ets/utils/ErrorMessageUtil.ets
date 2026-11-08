import axios from '@ohos/axios';
import { LoginErrorUtil } from './LoginErrorUtil';
import { LoginRequestError } from '../model/LoginError';
import { AppText, AppTextKey } from '../localization/AppText';
import { AppTextResolver } from '../localization/AppTextResolver';
import { LogSanitizer } from './LogSanitizer';

interface ErrorModelData {
  Message?: string | null;
  message?: string | null;
  ValidationErrors?: Record<string, string[] | string | null>;
  validationErrors?: Record<string, string[] | string | null>;
}

interface ErrorResponseData {
  message?: string | null;
  Message?: string | null;
  error?: string | null;
  error_description?: string | null;
  exceptionMessage?: string | null;
  validationErrors?: Record<string, string[] | string | null>;
  ValidationErrors?: Record<string, string[] | string | null>;
  ErrorModel?: ErrorModelData | null;
  errorModel?: ErrorModelData | null;
}

interface ErrorHttpResponse {
  status?: number;
  data?: ErrorResponseData | string | null;
}

interface ErrorLike {
  code?: string | number | null;
  cause?: Object;
  message?: string | null;
  response?: ErrorHttpResponse | null;
}

/** 从不同网络错误结构中提取诊断信息和候选用户消息 */
export class ErrorMessageUtil {
  /** 操作说明、可读原因和诊断码共用一个出口，前台和后台都保留原始异常。 */
  static getDisplayMessage(uiContext: UIContext, error: Object | string | null | undefined,
    fallback: ResourceStr): string {
    const resolve = (value: ResourceStr): string => typeof value === 'string' ? value :
      uiContext.getHostContext()?.resourceManager.getStringSync(value.id) ?? '';
    const parts: string[] = [resolve(fallback)];
    if (error === null || error === undefined) {
      return parts[0];
    }
    const normalized = ErrorMessageUtil.normalize(error);
    const code = String(normalized.code ?? '');
    const message = (normalized.message ?? '').toLowerCase();
    const key = LoginErrorUtil.classify(normalized as LoginRequestError);
    let reason = '';
    if (code === 'ETIMEDOUT' || code === 'ECONNABORTED' || code === '2300028' ||
      /timeout|timed out|time out/.test(message)) {
      reason = resolve($r('app.string.error_timeout'));
    } else if (code === 'ENOTFOUND' || code === 'EAI_AGAIN' || code === '2300006' ||
      /resolve host|name resolution|dns/.test(message)) {
      reason = resolve($r('app.string.error_dns'));
    } else if (code === 'ECONNREFUSED' || code === '2300007' || /connection refused|couldn.t connect/.test(message)) {
      reason = resolve($r('app.string.error_connection_refused'));
    } else if (/certificate|\bssl\b|\btls\b/.test(message)) {
      reason = resolve($r('app.string.error_tls'));
    } else if (code === 'ECONNRESET' || /connection reset|connection aborted|connection closed/.test(message)) {
      reason = resolve($r('app.string.error_connection_interrupted'));
    } else if (key !== AppTextKey.LOGIN_FAILED && (key !== AppTextKey.NETWORK_ERROR ||
      ErrorMessageUtil.isRequestFailure(error as Object) || normalized.response || /network/.test(message))) {
      reason = resolve(AppTextResolver.resource(new AppText(key)));
    }
    if (reason && reason !== parts[0]) {
      parts.push(resolve($r('app.string.error_reason_prefix')) + ': ' + reason);
    }
    const detail = ErrorMessageUtil.getUserMessage(error, '');
    // Axios 的 HTTP 包装信息和笼统 OAuth 标识由下面的状态/错误码展示。
    if (detail && detail !== reason && detail !== parts[0] &&
      !/^(request failed with status code \d+|network error|auth_session_expired)$/i.test(detail) &&
      !/^[a-z]+(?:_[a-z]+)+$/.test(detail)) {
      parts.push(resolve($r('app.string.error_details_prefix')) + ': ' + detail);
    }
    if (normalized.response?.status !== undefined) {
      parts.push(resolve($r('app.string.error_http_prefix')) + ': ' + normalized.response.status);
    }
    const body = normalized.response?.data;
    const businessCode = typeof body === 'object' && body ? body.error ?? '' : '';
    const codes = [code, businessCode].filter((value: string, index: number, values: string[]) =>
      value.length > 0 && values.indexOf(value) === index);
    if (codes.length > 0) {
      parts.push(resolve($r('app.string.error_code_prefix')) + ': ' + codes.join(' / '));
    }
    return parts.filter((value: string) => value.length > 0).join('\n\n');
  }

  private static normalize(error: Object | string, depth: number = 0): ErrorLike {
    if (typeof error === 'string') {
      return ErrorMessageUtil.normalize({ message: error } as ErrorLike);
    }
    const source = error as ErrorLike;
    const cause = source.cause && depth < 4 ? ErrorMessageUtil.normalize(source.cause, depth + 1) : undefined;
    const result: ErrorLike = { message: source.message ?? cause?.message, code: source.code ?? cause?.code,
      response: source.response ?? cause?.response };
    if (result.message) {
      try {
        const transport = JSON.parse(result.message) as ErrorLike;
        if (transport && typeof transport.message === 'string') {
          result.message = transport.message;
          result.code = transport.code ?? result.code;
          result.response = transport.response ?? result.response;
        }
      } catch (_) {
        // 普通错误文本。
      }
    }
    if (typeof result.response?.data === 'string') {
      try {
        const data = JSON.parse(result.response.data) as ErrorResponseData;
        if (data && typeof data === 'object') {
          result.response = { status: result.response.status, data: data };
        }
      } catch (_) {
        // 非 JSON 响应继续交由可读消息提取器处理。
      }
    }
    return result;
  }

  /** 仅识别 HTTP 客户端错误，避免把本地存储或解密失败标为请求失败 */
  static isRequestFailure(error: Object | null | undefined): boolean {
    return axios.isAxiosError(error);
  }

  /** 提取供 UI 展示的候选消息并限制长度，不序列化完整响应对象 */
  static getUserMessage(error: Object | string | null | undefined, fallback: string = '', depth: number = 0): string {
    if (error === null || error === undefined) {
      return fallback;
    }
    if (typeof error === 'string') {
      return ErrorMessageUtil.getUserMessage({ message: error } as ErrorLike, fallback, depth);
    }
    const errorLike = ErrorMessageUtil.normalize(error);
    const responseMessage = ErrorMessageUtil.getResponseDataMessage(errorLike.response?.data);
    if (responseMessage.length > 0) {
      return ErrorMessageUtil.limitMessage(responseMessage, fallback);
    }
    const cause = (error as ErrorLike).cause;
    if (cause && depth < 4) {
      const original = ErrorMessageUtil.getUserMessage(cause, '', depth + 1);
      if (original) {
        return original;
      }
    }
    if (errorLike.message && errorLike.message.length > 0) {
      // HarmonyOS 网络层可能把包含 extendInfo 的错误对象序列化进 message。
      // Toast 只透传实际错误消息，完整诊断仍由 getMessage 保留。
      let message = errorLike.message;
      try {
        const transportError = JSON.parse(message) as ErrorLike;
        if (transportError && typeof transportError.message === 'string') {
          message = transportError.message;
        }
      } catch (_) {
        // 普通错误文本直接使用。
      }
      return ErrorMessageUtil.limitMessage(message, fallback);
    }
    return fallback;
  }

  /** 提取完整诊断消息，供日志记录使用 */
  static getMessage(error: Object | string | null | undefined, fallback: string = 'error_unknown'): string {
    if (error === null || error === undefined) {
      return fallback;
    }

    if (typeof error === 'string') {
      return error.length > 0 ? error : fallback;
    }

    const errorLike = error as ErrorLike;
    const responseMessage = ErrorMessageUtil.getResponseDataMessage(errorLike.response?.data, true);
    if (responseMessage.length > 0) {
      return responseMessage;
    }

    if (errorLike.message && errorLike.message.length > 0) {
      return errorLike.message;
    }

    const serialized = ErrorMessageUtil.safeStringify(error);
    if (serialized.length > 0 && serialized !== '{}' && serialized !== '[]') {
      return serialized;
    }

    return fallback;
  }

  private static getResponseDataMessage(data?: ErrorResponseData | string | null, diagnostic: boolean = false): string {
    if (!data) {
      return '';
    }

    if (typeof data === 'string') {
      try {
        const parsed = JSON.parse(data) as ErrorResponseData;
        if (parsed && typeof parsed === 'object') {
          return ErrorMessageUtil.getResponseDataMessage(parsed, diagnostic);
        }
      } catch (_) {
        // 非 JSON 响应。
      }
      if (!diagnostic && /<\/?(?:html|body|head|script|!doctype)\b/i.test(data)) {
        return '';
      }
      return data;
    }

    const messages: string[] = [];
    ErrorMessageUtil.appendMessage(messages, data.ErrorModel?.Message);
    ErrorMessageUtil.appendMessage(messages, data.ErrorModel?.message);
    ErrorMessageUtil.appendMessage(messages, data.errorModel?.Message);
    ErrorMessageUtil.appendMessage(messages, data.errorModel?.message);
    ErrorMessageUtil.appendMessage(messages, data.message);
    ErrorMessageUtil.appendMessage(messages, data.Message);
    if (diagnostic || !/^[a-z]+(?:_[a-z]+)+$/.test(data.error_description ?? '')) {
      ErrorMessageUtil.appendMessage(messages, data.error_description);
    }
    if (diagnostic) {
      ErrorMessageUtil.appendMessage(messages, data.exceptionMessage);
      ErrorMessageUtil.appendMessage(messages, data.error);
    }

    const validationMessage = ErrorMessageUtil.getValidationErrorsMessage(data.validationErrors ?? data.ValidationErrors ??
      data.ErrorModel?.validationErrors ?? data.ErrorModel?.ValidationErrors ??
      data.errorModel?.validationErrors ?? data.errorModel?.ValidationErrors);
    ErrorMessageUtil.appendMessage(messages, validationMessage);

    return messages.join(' ');
  }

  private static getValidationErrorsMessage(validationErrors?: Record<string, string[] | string | null>): string {
    if (!validationErrors) {
      return '';
    }

    const messages: string[] = [];
    Object.keys(validationErrors).forEach((key: string) => {
      const value = validationErrors[key];
      if (!value) {
        return;
      }

      if (Array.isArray(value)) {
        const fieldMessage = (value as string[]).filter((item: string) => item.length > 0).join(' ');
        if (fieldMessage.length > 0) {
          messages.push(key ? `${key} — ${fieldMessage}` : fieldMessage);
        }
        return;
      }

      if (value.length > 0) {
        messages.push(key ? `${key} — ${value}` : value);
      }
    });

    return messages.join(' ');
  }

  private static appendMessage(messages: string[], message?: string | null): void {
    if (!message || message.length === 0) {
      return;
    }
    if (messages.indexOf(message) < 0) {
      messages.push(message);
    }
  }

  private static limitMessage(message: string, fallback: string): string {
    if (/<\/?(?:html|body|head|script|!doctype)\b/i.test(message)) {
      return fallback;
    }
    const normalized = LogSanitizer.sanitize(message.trim());
    if (normalized.length === 0) {
      return fallback;
    }
    return normalized.length > 4096 ? `${normalized.substring(0, 4096)}…` : normalized;
  }

  private static safeStringify(error: Object): string {
    try {
      return JSON.stringify(error);
    } catch (err) {
      return '';
    }
  }
}
