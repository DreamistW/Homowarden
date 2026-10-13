import { TwoFactorProviderData } from './AccessToken';

export interface LoginErrorModel {
  Message?: string;
  message?: string;
  Object?: string;
}

export interface LoginErrorResponseData {
  error?: string;
  error_description?: string;
  message?: string;
  ErrorModel?: LoginErrorModel;
  errorModel?: LoginErrorModel;
  TwoFactorProviders?: string[] | string;
  TwoFactorProviders2?: Record<string, TwoFactorProviderData | null>;
  SsoEmail2faSessionToken?: string;
}

export interface LoginRequestError {
  message?: string;
  response?: LoginErrorResponse;
}

export interface LoginErrorResponse {
  data?: LoginErrorResponseData;
  status?: number;
}
