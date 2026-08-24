import { deviceInfo } from '@kit.BasicServicesKit';

const PC_DEVICE_TYPE = '2in1';

/** 集中判断设备形态，供不同设备族的行为分支复用 */
export class FormFactorUtil {
  static isPc(): boolean {
    return deviceInfo.deviceType === PC_DEVICE_TYPE;
  }
}
