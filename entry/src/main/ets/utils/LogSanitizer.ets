/**
 * 对持久化和导出的诊断日志做统一脱敏。
 *
 * 规则只替换值并尽量保留字段名、错误码和调用路径，便于开发者排障。
 */
export class LogSanitizer {
  static sanitize(content: string): string {
    let sanitized = content;

    // 先处理带语义的敏感值，避免后续通用 URL/长字符串规则只遮盖其中一部分。
    sanitized = sanitized.replace(/otpauth:\/\/[^\s"']+/gi, '[REDACTED_OTP_URI]');
    sanitized = sanitized.replace(/Bearer\s+[^\s,"'}]+/gi, 'Bearer [REDACTED]');
    sanitized = sanitized.replace(
      /"(password|masterPasswordHash|username|email|deviceIdentifier|deviceName|access_token|refresh_token|token|twoFactorToken|newDeviceOtp|ssoEmail2faSessionToken|secret|key|privateKey|authorization|cookie)"\s*:\s*"[^"]*"/gi,
      '"$1":"[REDACTED]"'
    );
    sanitized = sanitized.replace(
      /(password|masterPasswordHash|username|email|deviceIdentifier|deviceName|access_token|refresh_token|token|twoFactorToken|newDeviceOtp|ssoEmail2faSessionToken|secret|key|privateKey|authorization|cookie)(\s*[:=]\s*)(["']?)[^\s,&}"']+/gi,
      '$1$2$3[REDACTED]'
    );

    sanitized = sanitized.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[REDACTED_EMAIL]');
    sanitized = sanitized.replace(/[A-Z0-9._%+-]+%40[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[REDACTED_EMAIL]');
    sanitized = sanitized.replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi,
      '[REDACTED_ID]');
    sanitized = sanitized.replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, '[REDACTED_IP]');
    sanitized = sanitized.replace(/(https:\/\/)[^\/\s"'?]+/gi, '$1[REDACTED_HOST]');
    sanitized = sanitized.replace(/(http:\/\/)[^\/\s"'?]+/gi, '$1[REDACTED_HOST]');
    sanitized = sanitized.replace(/\/data\/storage\/[^\s,"'}]+/gi, '[REDACTED_PATH]');

    // 最后兜底遮盖疑似编码凭据；短错误码、计数和普通英文单词不会命中。
    sanitized = sanitized.replace(/\b[A-Za-z0-9+\/_=-]{32,}\b/g, '[REDACTED_VALUE]');
    return sanitized;
  }

  static sanitizeContent(content: string | object | null): string | object | null {
    if (content === null) {
      return null;
    }
    if (typeof content === 'string') {
      return LogSanitizer.sanitize(content);
    }
    if (content instanceof Error) {
      return LogSanitizer.sanitize(`${content.name}: ${content.message}\n${content.stack ?? ''}`);
    }
    try {
      return LogSanitizer.sanitize(JSON.stringify(content));
    } catch (_) {
      return '[UNSERIALIZABLE_LOG_OBJECT]';
    }
  }
}
