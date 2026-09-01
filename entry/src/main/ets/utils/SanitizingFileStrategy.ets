import { FileStrategy } from '@nzy/logger';
import { LogSanitizer } from './LogSanitizer';

/** 在 Logger 写入应用私有文件前完成脱敏，避免磁盘上出现原始敏感日志。 */
export class SanitizingFileStrategy extends FileStrategy {
  constructor(filename: string) {
    super(filename);
  }

  public debug(tag: string, message: string | object | null): Promise<void> {
    return super.debug(tag, LogSanitizer.sanitizeContent(message));
  }

  public info(tag: string, message: string | object | null): Promise<void> {
    return super.info(tag, LogSanitizer.sanitizeContent(message));
  }

  public warn(tag: string, message: string | object | null): Promise<void> {
    return super.warn(tag, LogSanitizer.sanitizeContent(message));
  }

  public error(tag: string, message: string | object | null): Promise<void> {
    return super.error(tag, LogSanitizer.sanitizeContent(message));
  }

  public fatal(tag: string, message: string | object | null): Promise<void> {
    return super.fatal(tag, LogSanitizer.sanitizeContent(message));
  }
}
