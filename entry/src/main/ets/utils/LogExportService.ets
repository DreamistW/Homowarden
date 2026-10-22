import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { hiAppEvent } from '@kit.PerformanceAnalysisKit';
import { Logger } from '@nzy/logger';
import { LogSanitizer } from './LogSanitizer';
import { SanitizingFileStrategy } from './SanitizingFileStrategy';

const LOG_DIRECTORY = 'diagnostic_logs';
const SESSION_LOG_FILE = 'current-session.log';
const PREVIOUS_SESSION_LOG_FILE = 'previous-session.log';
const CRASH_LOG_FILE = 'crash-events.log';
const MAX_CRASH_LOG_CHARACTERS = 512 * 1024;
const EXPORT_PREFIX = 'Homowarden_';
const LEGACY_EXPORT_PREFIX = 'homowarden-logs-';

/** 管理当前启动会话的 Logger 文件和文件导出流程。 */
export class LogExportService {
  private static sessionLogPath: string = '';
  private static logDirectory: string = '';
  private static exportDirectory: string = '';
  private static exporting: boolean = false;
  private static crashWatcher?: hiAppEvent.Watcher;

  static initialize(context: common.UIAbilityContext): void {
    const logDirectory = `${context.filesDir}/${LOG_DIRECTORY}`;
    LogExportService.logDirectory = logDirectory;
    LogExportService.exportDirectory = context.cacheDir;
    try {
      LogExportService.clearOldExports(context.cacheDir);
      if (!fileIo.accessSync(logDirectory)) {
        fileIo.mkdirSync(logDirectory, true);
      }
      LogExportService.rotateSessionLog(logDirectory);
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
      LogExportService.registerCrashWatcher();
    } catch (error) {
      // 初始化失败时 Logger 仍可继续输出到 HiLog，不能因此阻止应用启动。
      console.error(`Failed to initialize diagnostic logging: ${LogExportService.errorMessage(error)}`);
    }
  }

  static async exportFile(uiContext: UIContext): Promise<boolean> {
    if (LogExportService.exporting || !LogExportService.sessionLogPath || !LogExportService.exportDirectory) {
      return false;
    }
    LogExportService.exporting = true;
    try {
      Logger.info('Preparing sanitized diagnostic log export');
      const sanitizedSnapshot = LogExportService.buildExportSnapshot();
      const context = uiContext.getHostContext() as common.UIAbilityContext;
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`${EXPORT_PREFIX}${LogExportService.timestamp()}.log`];
      options.fileSuffixChoices = ['Log|.log'];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) {
        return false;
      }
      const file = fileIo.openSync(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        const bytes = new util.TextEncoder().encodeInto(sanitizedSnapshot);
        let offset = 0;
        while (offset < bytes.length) {
          const written = fileIo.writeSync(file.fd, bytes.slice(offset).buffer);
          if (written <= 0) {
            throw new Error('Log export write failed');
          }
          offset += written;
        }
      } finally {
        fileIo.closeSync(file);
      }
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

  private static rotateSessionLog(logDirectory: string): void {
    const currentPath = `${logDirectory}/${SESSION_LOG_FILE}`;
    if (!fileIo.accessSync(currentPath)) {
      return;
    }
    const previousPath = `${logDirectory}/${PREVIOUS_SESSION_LOG_FILE}`;
    const previousSession = fileIo.readTextSync(currentPath, { encoding: 'utf-8' });
    LogExportService.writeSnapshot(previousPath, LogSanitizer.sanitize(previousSession));
    fileIo.unlinkSync(currentPath);
  }

  private static registerCrashWatcher(): void {
    if (LogExportService.crashWatcher) {
      return;
    }
    const watcher: hiAppEvent.Watcher = {
      name: 'homowardenCrashLogWatcher',
      appEventFilters: [{
        domain: hiAppEvent.domain.OS,
        names: [hiAppEvent.event.APP_CRASH]
      }],
      onReceive: (_domain: string, eventGroups: Array<hiAppEvent.AppEventGroup>): void => {
        eventGroups.forEach((eventGroup: hiAppEvent.AppEventGroup) => {
          eventGroup.appEventInfos.forEach((eventInfo: hiAppEvent.AppEventInfo) => {
            LogExportService.persistCrashEvent(eventInfo);
          });
        });
      }
    };
    LogExportService.crashWatcher = watcher;
    hiAppEvent.addWatcher(watcher);
  }

  private static persistCrashEvent(eventInfo: hiAppEvent.AppEventInfo): void {
    try {
      let entry = `\n===== APP_CRASH ${new Date().toISOString()} =====\n` +
        `${JSON.stringify(eventInfo.params)}\n`;
      const externalLogs = eventInfo.params['external_log'] as Array<string> | undefined;
      externalLogs?.forEach((path: string) => {
        try {
          entry += `\n--- external crash log ---\n${fileIo.readTextSync(path, { encoding: 'utf-8' })}\n`;
        } catch (error) {
          entry += `\n--- external crash log unavailable: ${LogExportService.errorMessage(error as Object)} ---\n`;
        }
      });

      const crashPath = `${LogExportService.logDirectory}/${CRASH_LOG_FILE}`;
      const oldContent = fileIo.accessSync(crashPath) ?
        fileIo.readTextSync(crashPath, { encoding: 'utf-8' }) : '';
      const combined = LogSanitizer.sanitize(oldContent + entry);
      const retained = combined.length > MAX_CRASH_LOG_CHARACTERS ?
        combined.substring(combined.length - MAX_CRASH_LOG_CHARACTERS) : combined;
      LogExportService.writeSnapshot(crashPath, retained);
      Logger.info('Previous application crash was added to the diagnostic archive');
    } catch (error) {
      Logger.error(`Failed to archive application crash: ${LogExportService.errorMessage(error as Object)}`);
    }
  }

  private static buildExportSnapshot(): string {
    const sections: Array<string> = [];
    LogExportService.addLogSection(sections, 'CRASH EVENTS', CRASH_LOG_FILE);
    LogExportService.addLogSection(sections, 'PREVIOUS SESSION', PREVIOUS_SESSION_LOG_FILE);
    LogExportService.addLogSection(sections, 'CURRENT SESSION', SESSION_LOG_FILE);
    return LogSanitizer.sanitize(sections.join('\n\n'));
  }

  private static addLogSection(sections: Array<string>, title: string, filename: string): void {
    const path = `${LogExportService.logDirectory}/${filename}`;
    if (!fileIo.accessSync(path)) {
      return;
    }
    const content = fileIo.readTextSync(path, { encoding: 'utf-8' });
    if (content.length > 0) {
      sections.push(`===== ${title} =====\n${content}`);
    }
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
