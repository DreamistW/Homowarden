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

/** 从 Axios 风格响应、业务错误和普通对象中提取可展示错误文本。 */
export class ErrorMessageUtil {
  /**
   * 按服务端错误模型、错误对象 message、可序列化对象、回退文案的顺序提取消息。
   * @param error 网络库错误、服务端字符串、普通对象或空值。
   * @param fallback 无可用消息时返回的用户文案。
   * @returns 去重并拼接验证错误后的非空消息；所有解析异常均在内部吸收。
   */
  static getMessage(error: Object | string | null | undefined, fallback: string = '未知错误'): string {
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

  /** 汇总兼容字段及逐字段验证错误，并保持服务端字段的优先顺序。 */
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

  private static safeStringify(error: Object): string {
    try {
      return JSON.stringify(error);
    } catch (err) {
      return '';
    }
  }
}
