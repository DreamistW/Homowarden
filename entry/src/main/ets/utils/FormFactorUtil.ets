import { deviceInfo } from '@kit.BasicServicesKit';

const RESPONSIVE_ORIENTATION_DEVICE_TYPES: string[] = ['phone', 'foldable', 'widefold', 'triplefold'];
const PC_DEVICE_TYPE = '2in1';

/** 集中判断设备形态，供不同设备族的行为分支复用 */
export class FormFactorUtil {
  static supportsResponsiveOrientation(): boolean {
    return RESPONSIVE_ORIENTATION_DEVICE_TYPES.includes(deviceInfo.deviceType);
  }

  static isPc(): boolean {
    return deviceInfo.deviceType === PC_DEVICE_TYPE;
  }
}
