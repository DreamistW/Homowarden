import axios from '@ohos/axios';

interface ErrorModelData {
  Message?: string | null;
  message?: string | null;
}

interface ErrorResponseData {
  message?: string | null;
  Message?: string | null;
  error?: string | null;
  error_description?: string | null;
  exceptionMessage?: string | null;
  validationErrors?: Record<string, string[] | string | null>;
  ErrorModel?: ErrorModelData | null;
  errorModel?: ErrorModelData | null;
}

interface ErrorHttpResponse {
  data?: ErrorResponseData | string | null;
}

interface ErrorLike {
  message?: string | null;
  response?: ErrorHttpResponse | null;
}

/** 从不同网络错误结构中提取诊断信息和候选用户消息 */
export class ErrorMessageUtil {
  /** 仅识别 HTTP 客户端错误，避免把本地存储或解密失败标为请求失败 */
  static isRequestFailure(error: Object | null | undefined): boolean {
    return axios.isAxiosError(error);
  }

  /** 提取供 UI 展示的候选消息并限制长度，不序列化完整响应对象 */
  static getUserMessage(error: Object | string | null | undefined, fallback: string = ''): string {
    if (error === null || error === undefined) {
      return fallback;
    }
    if (typeof error === 'string') {
      return ErrorMessageUtil.limitMessage(error, fallback);
    }
    const errorLike = error as ErrorLike;
    const responseMessage = ErrorMessageUtil.getResponseDataMessage(errorLike.response?.data);
    if (responseMessage.length > 0) {
      return ErrorMessageUtil.limitMessage(responseMessage, fallback);
    }
    if (errorLike.message && errorLike.message.length > 0) {
      return ErrorMessageUtil.limitMessage(errorLike.message, fallback);
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
    const responseMessage = ErrorMessageUtil.getResponseDataMessage(errorLike.response?.data);
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

  private static getResponseDataMessage(data?: ErrorResponseData | string | null): string {
    if (!data) {
      return '';
    }

    if (typeof data === 'string') {
      return data;
    }

    const messages: string[] = [];
    ErrorMessageUtil.appendMessage(messages, data.ErrorModel?.Message);
    ErrorMessageUtil.appendMessage(messages, data.ErrorModel?.message);
    ErrorMessageUtil.appendMessage(messages, data.errorModel?.Message);
    ErrorMessageUtil.appendMessage(messages, data.errorModel?.message);
    ErrorMessageUtil.appendMessage(messages, data.message);
    ErrorMessageUtil.appendMessage(messages, data.Message);
    ErrorMessageUtil.appendMessage(messages, data.error_description);
    ErrorMessageUtil.appendMessage(messages, data.exceptionMessage);
    ErrorMessageUtil.appendMessage(messages, data.error);

    const validationMessage = ErrorMessageUtil.getValidationErrorsMessage(data.validationErrors);
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
          messages.push(`${key}: ${fieldMessage}`);
        }
        return;
      }

      if (value.length > 0) {
        messages.push(`${key}: ${value}`);
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
    const normalized = message.trim();
    if (normalized.length === 0) {
      return fallback;
    }
    return normalized.length > 240 ? `${normalized.substring(0, 240)}…` : normalized;
  }

  private static safeStringify(error: Object): string {
    try {
      return JSON.stringify(error);
    } catch (err) {
      return '';
    }
  }
}
