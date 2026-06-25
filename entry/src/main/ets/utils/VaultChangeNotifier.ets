import { Cipher } from '../model/CipherModels';

export enum VaultLocalChangeType {
  UPSERT = 0,
  DELETE = 1
}

export interface VaultLocalChange {
  type: VaultLocalChangeType;
  cipher?: Cipher;
  cipherId?: string;
}

let pendingChange: VaultLocalChange | null = null;
let changeRevision: number = 0;

export class VaultChangeNotifier {
  static markLocalChangePending(): void {
    changeRevision++;
  }

  static setUpdatedCipher(cipher: Cipher): void {
    pendingChange = {
      type: VaultLocalChangeType.UPSERT,
      cipher: cipher
    };
    changeRevision++;
  }

  static setDeletedCipher(cipherId: string): void {
    pendingChange = {
      type: VaultLocalChangeType.DELETE,
      cipherId: cipherId
    };
    changeRevision++;
  }

  static getChangeRevision(): number {
    return changeRevision;
  }

  static consumeChange(): VaultLocalChange | null {
    const change = pendingChange;
    pendingChange = null;
    return change;
  }

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
