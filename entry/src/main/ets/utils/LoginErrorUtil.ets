import { LoginErrorResponseData } from '../model/LoginError';
import { LoginRequestError } from '../model/LoginError';
import { AppTextKey } from '../localization/AppText';

export class LoginErrorUtil {
  static getModelMessage(data?: LoginErrorResponseData): string {
    return data?.ErrorModel?.Message || data?.ErrorModel?.message ||
      data?.errorModel?.Message || data?.errorModel?.message || '';
  }

  static isNewDeviceVerificationRequired(data?: LoginErrorResponseData): boolean {
    return LoginErrorUtil.matches(data, 'new device verification required');
  }

  static isInvalidCredentials(data?: LoginErrorResponseData): boolean {
    return LoginErrorUtil.matches(data, 'invalid_username_or_password') ||
      LoginErrorUtil.matches(data, 'username or password is incorrect. try again');
  }

  static isInvalidVerificationCode(data?: LoginErrorResponseData): boolean {
    const message = LoginErrorUtil.messages(data);
    return message.includes('verification code') || message.includes('two-factor token') ||
      message.includes('two factor token') || message.includes('invalid new device otp') ||
      message.includes('invalid otp') || message.includes('two-step token is invalid');
  }

  static providers(data?: LoginErrorResponseData): number[] {
    const modern = data?.TwoFactorProviders2 ? Object.keys(data.TwoFactorProviders2) : [];
    if (modern.length > 0) {
      return modern.map((value: string) => Number(value)).filter((value: number) => Number.isInteger(value));
    }
    const legacy = data?.TwoFactorProviders;
    const values = Array.isArray(legacy) ? legacy : (typeof legacy === 'string' ? legacy.match(/\d+/g) ?? [] : []);
    return values.map((value: string) => Number(value)).filter((value: number) => Number.isInteger(value));
  }

  static isTwoFactorRequired(data?: LoginErrorResponseData): boolean {
    return LoginErrorUtil.providers(data).length > 0 ||
      LoginErrorUtil.messages(data).includes('two factor required');
  }

  static classify(error: LoginRequestError): AppTextKey {
    if (error.message === 'Device identifier persistence failed') {
      return AppTextKey.STORAGE_ERROR;
    }
    const data = error.response?.data;
    const message = LoginErrorUtil.messages(data);
    if (error.message?.toLowerCase().includes('timeout')) {
      return AppTextKey.TIMEOUT_ERROR;
    }
    if (!error.response) {
      return AppTextKey.NETWORK_ERROR;
    }
    if (error.response.status === 429 || message.includes('too many requests') || message.includes('rate limit')) {
      return AppTextKey.RATE_LIMITED;
    }
    if (message.includes('verify your email')) {
      return AppTextKey.EMAIL_UNVERIFIED;
    }
    if (message.includes('user has been disabled') || message.includes('account is disabled')) {
      return AppTextKey.ACCOUNT_DISABLED;
    }
    if (message.includes('sso') || message.includes('single sign-on')) {
      return AppTextKey.SSO_REQUIRED;
    }
    if (message.includes('legacy') || message.includes('encryption key migration') ||
      message.includes('key connector')) {
      return AppTextKey.ACCOUNT_MIGRATION_REQUIRED;
    }
    if (message.includes('invalid_client_version') || message.includes('version_header_missing')) {
      return AppTextKey.CLIENT_VERSION_UNSUPPORTED;
    }
    if (error.response.status === 403 || message.includes('captcha') || message.includes('unusual traffic') ||
      message.includes('cf-chl-') || message.includes('cloudflare')) {
      return AppTextKey.ACCESS_RESTRICTED;
    }
    if (LoginErrorUtil.isInvalidCredentials(data)) {
      return AppTextKey.INVALID_CREDENTIALS;
    }
    if (LoginErrorUtil.isInvalidVerificationCode(data)) {
      return AppTextKey.CODE_INVALID;
    }
    return data?.error === 'device_error' ? AppTextKey.DEVICE_VERIFICATION_FAILED : AppTextKey.LOGIN_FAILED;
  }

  private static messages(data?: LoginErrorResponseData): string {
    if (typeof data === 'string') {
      return (data as string).toLowerCase();
    }
    return [LoginErrorUtil.getModelMessage(data), data?.message ?? '', data?.error_description ?? '',
      data?.error ?? ''].join(' ').toLowerCase();
  }

  private static matches(data: LoginErrorResponseData | undefined, expected: string): boolean {
    const messages = [LoginErrorUtil.getModelMessage(data), data?.message ?? '', data?.error_description ?? ''];
    return messages.some((message: string) => message.trim().toLowerCase().replace(/[.!]+$/, '') === expected);
  }
}
