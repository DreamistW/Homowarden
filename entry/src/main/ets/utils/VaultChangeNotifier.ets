import { Cipher } from '../model/CipherModels';

export enum VaultLocalChangeType {
  UPSERT = 0,
  DELETE = 1,
  RELOAD = 2
}

export interface VaultLocalChange {
  type: VaultLocalChangeType;
  cipher?: Cipher;
  cipherId?: string;
}

let pendingChange: VaultLocalChange | null = null;
let changeRevision: number = 0;
const COMMITTED_CHANGE_REVISION_KEY = 'vaultCommittedChangeRevision';

export class VaultChangeNotifier {
  static setVaultReloadRequired(): void {
    pendingChange = { type: VaultLocalChangeType.RELOAD };
    changeRevision++;
    VaultChangeNotifier.notifyCommittedChange();
  }

  static initialize(): void {
    AppStorage.setOrCreate(COMMITTED_CHANGE_REVISION_KEY, 0);
  }

  static markLocalChangePending(): void {
    changeRevision++;
  }

  static setUpdatedCipher(cipher: Cipher): void {
    pendingChange = {
      type: VaultLocalChangeType.UPSERT,
      cipher: cipher
    };
    changeRevision++;
    VaultChangeNotifier.notifyCommittedChange();
  }

  static setDeletedCipher(cipherId: string): void {
    pendingChange = {
      type: VaultLocalChangeType.DELETE,
      cipherId: cipherId
    };
    changeRevision++;
    VaultChangeNotifier.notifyCommittedChange();
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

  private static notifyCommittedChange(): void {
    const revision = AppStorage.get<number>(COMMITTED_CHANGE_REVISION_KEY) ?? 0;
    AppStorage.setOrCreate(COMMITTED_CHANGE_REVISION_KEY, revision + 1);
  }
}
