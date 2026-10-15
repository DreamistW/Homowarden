/** 认证请求统一使用较长超时；不自动重试带凭据的请求。 */
export const AUTH_TIMEOUT_MS = 30000;

export class AuthProtocolUtil {
  static origin(baseUrl: string): string {
    const match = baseUrl.match(/^(https?:\/\/[^\/?#]+)(?:[\/?#]|$)/i);
    if (!match || match[1].includes('@')) {
      throw new Error('Invalid authentication origin');
    }
    return match[1];
  }
}
