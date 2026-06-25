import { Cipher } from '../model/CipherModels';

let pendingUpdatedCipher: Cipher | null = null;

export class VaultChangeNotifier {
  static setUpdatedCipher(cipher: Cipher): void {
    pendingUpdatedCipher = cipher;
  }

  static consumeUpdatedCipher(): Cipher | null {
    const cipher = pendingUpdatedCipher;
    pendingUpdatedCipher = null;
    return cipher;
  }

  static clearUpdatedCipher(cipherId: string): void {
    if (pendingUpdatedCipher && pendingUpdatedCipher.id === cipherId) {
      pendingUpdatedCipher = null;
    }
  }
}
