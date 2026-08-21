import { i18n } from '@kit.LocalizationKit';
import { LocaleUtil } from '../localization/LocaleUtil';

const MILLISECONDS_PER_MINUTE: number = 60 * 1000;
const MILLISECONDS_PER_HOUR: number = 60 * MILLISECONDS_PER_MINUTE;
const MINIMUM_MILLISECOND_TIMESTAMP: number = 100000000000;

/** Formats history timestamps consistently with the system locale and clock preference. */
export class HistoryTimeFormatter {
  static format(timestamp: number, now: number = Date.now()): string {
    const normalizedTimestamp: number = HistoryTimeFormatter.normalizeTimestamp(timestamp);
    const date: Date = new Date(normalizedTimestamp);
    if (Number.isNaN(date.getTime())) {
      return '';
    }

    const difference: number = now - normalizedTimestamp;
    if (difference >= -MILLISECONDS_PER_MINUTE && difference < MILLISECONDS_PER_HOUR) {
      const minutes: number = Math.max(0, Math.floor(difference / MILLISECONDS_PER_MINUTE));
      return new Intl.RelativeTimeFormat(LocaleUtil.getLanguage(), { numeric: 'auto' })
        .format(minutes === 0 ? 0 : -minutes, minutes === 0 ? 'second' : 'minute');
    }

    return new Intl.DateTimeFormat(LocaleUtil.getLanguage(), {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: !i18n.System.is24HourClock()
    }).format(date);
  }

  private static normalizeTimestamp(timestamp: number): number {
    if (timestamp > 0 && timestamp < MINIMUM_MILLISECOND_TIMESTAMP) {
      return timestamp * 1000;
    }
    return timestamp;
  }
}
