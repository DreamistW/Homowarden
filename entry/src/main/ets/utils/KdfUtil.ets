import { KdfParameters, PreloginResponse } from '../model/Prelogin';

/** 将新旧预登录和历史资产记录转换为同一组参数，不用默认值替换服务端参数。 */
export class KdfUtil {
  static normalize(response: PreloginResponse, email: string): KdfParameters {
    const settings = response.kdfSettings;
    const type = settings ? settings.kdfType : response.kdf;
    const iterations = settings ? settings.iterations : response.kdfIterations;
    const memory = settings ? settings.memory : response.kdfMemory;
    const parallelism = settings ? settings.parallelism : response.kdfParallelism;
    if (type !== 0 && type !== 1) {
      throw new Error('Unsupported KDF type');
    }
    if (!KdfUtil.isPositiveInteger(iterations)) {
      throw new Error('Invalid KDF iterations');
    }
    if (type === 1 && (!KdfUtil.isPositiveInteger(memory) || !KdfUtil.isPositiveInteger(parallelism) ||
      (memory as number) > Math.floor(0xFFFFFFFF / 1024) ||
      (memory as number) * 1024 < 8 * (parallelism as number))) {
      throw new Error('Invalid Argon2id parameters');
    }
    if (response.salt !== undefined && response.salt !== null && typeof response.salt !== 'string') {
      throw new Error('Invalid KDF salt');
    }
    // 官方 MasterKey 派生对盐做 trim/lowercase；只有缺失或 null 才回退到邮箱。
    const salt = (response.salt ?? email).trim().toLowerCase();
    return {
      kdf: type,
      kdfIterations: iterations as number,
      kdfMemory: type === 1 ? memory as number : 0,
      kdfParallelism: type === 1 ? parallelism as number : 0,
      salt: salt
    };
  }

  private static isPositiveInteger(value: number | null | undefined): boolean {
    return typeof value === 'number' && Number.isInteger(value) && value > 0 && value <= 0x7FFFFFFF;
  }
}
