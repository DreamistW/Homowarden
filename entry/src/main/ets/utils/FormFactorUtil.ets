import { deviceInfo } from '@kit.BasicServicesKit';

const PC_DEVICE_TYPE = '2in1';

/** Provides shared form-factor checks for behavior that differs by device family. */
export class FormFactorUtil {
  static isPc(): boolean {
    return deviceInfo.deviceType === PC_DEVICE_TYPE;
  }
}
