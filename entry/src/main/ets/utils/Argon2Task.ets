import { argon2Hash, HashOption } from '@huozhiniao/argon2';
import { util } from '@kit.ArkTS';
import { hidebug } from '@kit.PerformanceAnalysisKit';

/** 仅在 TaskPool 线程调用原生同步库；不记录密码、盐或派生结果。 */
@Concurrent
export function deriveArgon2(password: Uint8Array, salt: Uint8Array, iterations: number,
  memory: number, parallelism: number, keyLen: number): string {
  try {
    // 单位为 KiB；在工作线程中检查，给运行时和原生库保留 64 MiB 余量。
    if (Number(hidebug.getSystemMemInfo().availableMem) < memory * 1024 + 64 * 1024) {
      throw new Error('argon2_resources_unavailable');
    }
    const option: HashOption = new HashOption();
    option.timeCost = iterations;
    option.memoryCost = memory * 1024;
    option.parallelism = parallelism;
    option.hashLength = keyLen;
    option.argon2Type = 2;
    option.argon2Version = 19;
    const result = argon2Hash(password.buffer, salt.buffer, option);
    if (result.result !== 'ARGON2_OK') {
      const failure = result.result.toLowerCase();
      if (failure.includes('memory') || failure.includes('thread')) {
        throw new Error('argon2_resources_unavailable');
      }
      throw new Error('Argon2 computation failed');
    }
    const hash = new Uint8Array(result.hash);
    try {
      return new util.Base64Helper().encodeToStringSync(hash);
    } finally {
      hash.fill(0);
    }
  } finally {
    password.fill(0);
    salt.fill(0);
  }
}
