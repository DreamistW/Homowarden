import { TwoFactorProviderData } from './AccessToken';

/** 为业务分类添加上下文，同时保留原始 HTTP/系统错误及原因。 */
export class LoginOperationError extends Error {
  cause: Object;

  constructor(message: string, cause: Object) {
    super(message);
    this.cause = cause;
  }
}

export interface LoginErrorModel {
  Message?: string;
  message?: string;
  Object?: string;
  ValidationErrors?: Record<string, string[] | string | null>;
  validationErrors?: Record<string, string[] | string | null>;
}

export interface LoginErrorResponseData {
  error?: string;
  error_description?: string;
  message?: string;
  Message?: string;
  validationErrors?: Record<string, string[] | string | null>;
  ValidationErrors?: Record<string, string[] | string | null>;
  ErrorModel?: LoginErrorModel;
  errorModel?: LoginErrorModel;
  TwoFactorProviders?: string[] | string;
  TwoFactorProviders2?: Record<string, TwoFactorProviderData | null>;
  SsoEmail2faSessionToken?: string;
}

export interface LoginRequestError {
  code?: string | number;
  message?: string;
  response?: LoginErrorResponse;
}

export interface LoginErrorResponse {
  data?: LoginErrorResponseData;
  status?: number;
}
