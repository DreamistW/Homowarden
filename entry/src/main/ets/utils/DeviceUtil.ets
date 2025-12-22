import { Logger } from '@nzy/logger';
import { DataPreferences } from '@abner/datastore';
import { DEVICE_ID_KEY, DeviceType } from './Constants';
import { DeviceInfo } from '../model/DeviceInfo';

/**
 * 设备信息管理工具类
 * 用于获取和管理设备相关信息
 */
export class DeviceUtil {
  /**
   * 获取设备类型
   * @returns 设备类型数字
   */
  static getDeviceType(): number {
    // 使用Android设备类型
    return DeviceType.CHROME;
  }

  /**
   * 获取设备名称
   * @returns 设备名称字符串
   */
  static getDeviceName(): string {
    // 可以根据实际需求自定义设备名称
    return 'Homowarden';
  }

  /**
   * 生成UUID格式的设备标识符
   * @returns UUID格式的字符串
   */
  static generateUUID(): string {
    const hexDigits = '0123456789abcdef';
    let uuid = '';
    for (let i = 0; i < 36; i++) {
      if (i === 8 || i === 13 || i === 18 || i === 23) {
        uuid += '-';
      } else if (i === 14) {
        uuid += '4';
      } else if (i === 19) {
        uuid += hexDigits.charAt(((Math.random() * 4) | 8));
      } else {
        uuid += hexDigits.charAt((Math.random() * 16) | 0);
      }
    }
    return uuid;
  }

  /**
   * 获取或生成设备标识符
   * @returns Promise<string> 设备标识符
   */
  static async getOrGenerateDeviceIdentifier(): Promise<string> {
    let deviceId = '';
    await DataPreferences.getInstance().getPromise(DEVICE_ID_KEY, '').then((data: string) => {
      deviceId = data;
    })
    if (!deviceId) {
      deviceId = DeviceUtil.generateUUID();
      DataPreferences.getInstance().put(DEVICE_ID_KEY, deviceId, (isSuccess: boolean, error) => {
        if (!isSuccess) {
          Logger.error("Save device id failed, error message: " + error?.message);
        }
      })
      Logger.debug(`Generated new device identifier: ${deviceId}`);
    } else {
      Logger.debug(`Retrieved existing device identifier: ${deviceId}`);
    }
    return deviceId;
  }

  /**
   * 获取完整的设备信息
   * @returns Promise<设备信息对象>
   */
  static async getDeviceInfo(): Promise<DeviceInfo> {
    const deviceIdentifier = await DeviceUtil.getOrGenerateDeviceIdentifier();

    return {
      deviceType: DeviceUtil.getDeviceType(),
      deviceName: DeviceUtil.getDeviceName(),
      deviceIdentifier: deviceIdentifier
    };
  }

  /**
   * 验证设备类型是否有效
   * @param deviceType 设备类型
   * @returns 是否有效
   */
  static isValidDeviceType(deviceType: number): boolean {
    const validTypes = [
      DeviceType.ANDROID,
      DeviceType.IOS,
      DeviceType.CHROME,
      DeviceType.FIREFOX,
      DeviceType.OPERA,
      DeviceType.EDGE,
      DeviceType.WINDOWS,
      DeviceType.MACOS,
      DeviceType.LINUX,
      DeviceType.SDK
    ];
    return validTypes.includes(deviceType);
  }

  /**
   * 获取设备类型描述
   * @param deviceType 设备类型
   * @returns 设备类型描述
   */
  static getDeviceTypeDescription(deviceType: number): string {
    switch (deviceType) {
      case DeviceType.ANDROID:
        return 'Android';
      case DeviceType.IOS:
        return 'iOS';
      case DeviceType.CHROME:
        return 'Chrome';
      case DeviceType.FIREFOX:
        return 'Firefox';
      case DeviceType.OPERA:
        return 'Opera';
      case DeviceType.EDGE:
        return 'Edge';
      case DeviceType.WINDOWS:
        return 'Windows';
      case DeviceType.MACOS:
        return 'macOS';
      case DeviceType.LINUX:
        return 'Linux';
      case DeviceType.SDK:
        return 'SDK';
      default:
        return 'Unknown';
    }
  }

  /**
   * 清除保存的设备标识符（用于测试或重置）
   */
  static async clearDeviceIdentifier(): Promise<void> {
    DataPreferences.getInstance().delete(DEVICE_ID_KEY);
    Logger.debug('Device identifier cleared from DataStore');
  }

  // 生成时间戳
  static getISOTimestamp() {
    const now = new Date();
    return now.toISOString();
  }
}
