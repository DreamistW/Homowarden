import { LoginErrorResponseData } from '../model/LoginError';

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
    const message = (LoginErrorUtil.getModelMessage(data) || data?.message ||
      data?.error_description || '').toLowerCase();
    return message.includes('verification code') || message.includes('two-factor token') ||
      message.includes('two factor token') || message.includes('invalid new device otp') ||
      message.includes('invalid otp');
  }

  private static matches(data: LoginErrorResponseData | undefined, expected: string): boolean {
    const messages = [LoginErrorUtil.getModelMessage(data), data?.message ?? '', data?.error_description ?? ''];
    return messages.some((message: string) => message.trim().toLowerCase().replace(/[.!]+$/, '') === expected);
  }
}
