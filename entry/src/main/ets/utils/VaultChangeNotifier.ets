import { Cipher } from '../model/CipherModels';

/** 本地密码库变更对列表的影响类型；数值用于进程内判别。 */
export enum VaultLocalChangeType {
  UPSERT = 0,
  DELETE = 1
}

/** 页面间传递的一次性本地密码项变更。 */
export interface VaultLocalChange {
  type: VaultLocalChangeType;
  cipher?: Cipher;
  cipherId?: string;
}

let pendingChange: VaultLocalChange | null = null;
let changeRevision: number = 0;

/**
 * 维护单槽本地变更与单调递增的修订号。
 *
 * 新变更会覆盖尚未消费的旧变更；消费操作清空槽位，但不会回退修订号。
 */
export class VaultChangeNotifier {
  /** 仅提升修订号，表示调用方需要重新检查数据，但不提供增量内容。 */
  static markLocalChangePending(): void {
    changeRevision++;
  }

  /** 记录可直接合并到列表的新增或更新密码项，并提升修订号。 */
  static setUpdatedCipher(cipher: Cipher): void {
    pendingChange = {
      type: VaultLocalChangeType.UPSERT,
      cipher: cipher
    };
    changeRevision++;
  }

  /** 记录应从列表移除的密码项 ID，并提升修订号。 */
  static setDeletedCipher(cipherId: string): void {
    pendingChange = {
      type: VaultLocalChangeType.DELETE,
      cipherId: cipherId
    };
    changeRevision++;
  }

  /** @returns 自进程启动以来记录本地变更的累计版本。 */
  static getChangeRevision(): number {
    return changeRevision;
  }

  /** @returns 当前待处理变更；读取后立即清空，后续调用返回 `null`。 */
  static consumeChange(): VaultLocalChange | null {
    const change = pendingChange;
    pendingChange = null;
    return change;
  }

  /** 兼容仅关心更新事件的调用方；删除事件也会被消费并返回 `null`。 */
  static consumeUpdatedCipher(): Cipher | null {
    const change = VaultChangeNotifier.consumeChange();
    if (change?.type === VaultLocalChangeType.UPSERT) {
      return change.cipher || null;
    }
    return null;
  }

  static clearUpdatedCipher(cipherId: string): void {
    if (pendingChange?.cipher?.id === cipherId || pendingChange?.cipherId === cipherId) {
      pendingChange = null;
    }
  }
}
