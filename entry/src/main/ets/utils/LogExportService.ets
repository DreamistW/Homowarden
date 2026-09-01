import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { Logger } from '@nzy/logger';
import { LogSanitizer } from './LogSanitizer';
import { SanitizingFileStrategy } from './SanitizingFileStrategy';

const LOG_DIRECTORY = 'diagnostic_logs';
const SESSION_LOG_FILE = 'current-session.log';
const EXPORT_PREFIX = 'Homowarden_';
const LEGACY_EXPORT_PREFIX = 'homowarden-logs-';

/** 管理当前启动会话的 Logger 文件和系统分享流程。 */
export class LogExportService {
  private static sessionLogPath: string = '';
  private static exportDirectory: string = '';
  private static exporting: boolean = false;

  static initialize(context: common.UIAbilityContext): void {
    const logDirectory = `${context.filesDir}/${LOG_DIRECTORY}`;
    LogExportService.exportDirectory = context.cacheDir;
    try {
      LogExportService.clearDirectory(logDirectory);
      LogExportService.clearOldExports(context.cacheDir);
      if (!fileIo.accessSync(logDirectory)) {
        fileIo.mkdirSync(logDirectory, true);
      }
      LogExportService.sessionLogPath = `${logDirectory}/${SESSION_LOG_FILE}`;
      Logger.init({
        tag: 'Homowarden',
        parentPath: logDirectory,
        isEnable: true,
        isShowFile: true,
        jsonWrite: true,
        debugLevelWrite: true
      }, new SanitizingFileStrategy(SESSION_LOG_FILE));
      Logger.info('Diagnostic log session started');
    } catch (error) {
      // 初始化失败时 Logger 仍可继续输出到 HiLog，不能因此阻止应用启动。
      console.error(`Failed to initialize diagnostic logging: ${LogExportService.errorMessage(error)}`);
    }
  }

  static async exportAndShare(uiContext: UIContext): Promise<boolean> {
    if (LogExportService.exporting || !LogExportService.sessionLogPath || !LogExportService.exportDirectory) {
      return false;
    }
    LogExportService.exporting = true;
    try {
      Logger.info('Preparing sanitized diagnostic log export');
      const sessionLog = fileIo.readTextSync(LogExportService.sessionLogPath, { encoding: 'utf-8' });
      const sanitizedSnapshot = LogSanitizer.sanitize(sessionLog);
      const exportPath = `${LogExportService.exportDirectory}/${EXPORT_PREFIX}${LogExportService.timestamp()}.log`;
      LogExportService.writeSnapshot(exportPath, sanitizedSnapshot);

      const sharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        uri: fileUri.getUriFromPath(exportPath)
      });
      const controller = new systemShare.ShareController(sharedData);
      const context = uiContext.getHostContext() as common.UIAbilityContext;
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
      return true;
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error(`Failed to export diagnostic logs. Code: ${businessError.code ?? 0}, message: ${businessError.message ?? ''}`);
      return false;
    } finally {
      LogExportService.exporting = false;
    }
  }

  private static writeSnapshot(path: string, content: string): void {
    const file = fileIo.openSync(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, content);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static clearDirectory(path: string): void {
    if (!fileIo.accessSync(path)) {
      return;
    }
    const names = fileIo.listFileSync(path);
    names.forEach((name: string) => {
      const childPath = `${path}/${name}`;
      if (fileIo.statSync(childPath).isFile()) {
        fileIo.unlinkSync(childPath);
      }
    });
  }

  private static clearOldExports(cacheDirectory: string): void {
    if (!fileIo.accessSync(cacheDirectory)) {
      return;
    }
    fileIo.listFileSync(cacheDirectory).forEach((name: string) => {
      const isCurrentExport = name.startsWith(EXPORT_PREFIX) && name.endsWith('.log');
      const isLegacyExport = name.startsWith(LEGACY_EXPORT_PREFIX) && name.endsWith('.txt');
      if (isCurrentExport || isLegacyExport) {
        fileIo.unlinkSync(`${cacheDirectory}/${name}`);
      }
    });
  }

  private static timestamp(): string {
    const date = new Date();
    const pad = (value: number): string => value.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}-` +
      `${pad(date.getHours())}-${pad(date.getMinutes())}-${pad(date.getSeconds())}`;
  }

  private static errorMessage(error: Object): string {
    const businessError = error as BusinessError;
    return businessError.message ?? String(error);
  }
}
