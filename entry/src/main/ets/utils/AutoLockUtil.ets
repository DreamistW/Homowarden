import { DataPreferences } from '@abner/datastore';
import { Logger } from '@nzy/logger';
import { AUTO_LOCK_TIMEOUT, AutoLockTimeout } from './Constants';

const LEGACY_AUTO_LOCK_ENABLED = 1;

export class AutoLockUtil {
  private static lastActivityAtMs: number = Date.now();

  static getTimeoutSeconds(): AutoLockTimeout {
    try {
      const storedValue = DataPreferences.getInstance().getSync<number>(AUTO_LOCK_TIMEOUT);
      const normalizedValue = AutoLockUtil.normalizeTimeout(storedValue);
      if (normalizedValue !== storedValue) {
        DataPreferences.getInstance().putSync(AUTO_LOCK_TIMEOUT, normalizedValue);
      }
      return normalizedValue;
    } catch (error) {
      Logger.error(`Failed to load auto-lock timeout. Error: ${JSON.stringify(error)}`);
      return AutoLockTimeout.NEVER;
    }
  }

  static setTimeoutSeconds(timeoutSeconds: number): AutoLockTimeout {
    const normalizedValue = AutoLockUtil.normalizeTimeout(timeoutSeconds);
    DataPreferences.getInstance().putSync(AUTO_LOCK_TIMEOUT, normalizedValue);
    AutoLockUtil.recordActivity();
    return normalizedValue;
  }

  static recordActivity(activityAtMs: number = Date.now()): void {
    AutoLockUtil.lastActivityAtMs = activityAtMs;
  }

  static hasTimedOut(currentTimeMs: number = Date.now()): boolean {
    const timeoutSeconds = AutoLockUtil.getTimeoutSeconds();
    if (timeoutSeconds === AutoLockTimeout.NEVER) {
      return false;
    }
    return currentTimeMs - AutoLockUtil.lastActivityAtMs >= timeoutSeconds * 1000;
  }

  private static normalizeTimeout(timeoutSeconds: number): AutoLockTimeout {
    switch (timeoutSeconds) {
      case LEGACY_AUTO_LOCK_ENABLED:
      case AutoLockTimeout.ONE_MINUTE:
        return AutoLockTimeout.ONE_MINUTE;
      case AutoLockTimeout.FIVE_MINUTES:
        return AutoLockTimeout.FIVE_MINUTES;
      case AutoLockTimeout.FIFTEEN_MINUTES:
        return AutoLockTimeout.FIFTEEN_MINUTES;
      case AutoLockTimeout.THIRTY_MINUTES:
        return AutoLockTimeout.THIRTY_MINUTES;
      case AutoLockTimeout.ONE_HOUR:
        return AutoLockTimeout.ONE_HOUR;
      case AutoLockTimeout.FOUR_HOURS:
        return AutoLockTimeout.FOUR_HOURS;
      case AutoLockTimeout.NEVER:
      default:
        return AutoLockTimeout.NEVER;
    }
  }
}
