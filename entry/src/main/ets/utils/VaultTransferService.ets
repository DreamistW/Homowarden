import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Cipher, CipherCard, CipherIdentity } from '../model/CipherModels';
import { importCiphers } from '../network/CipherApi';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { CipherDetailViewModel } from '../viewmodel/CipherDetailViewModel';
import { CipherDisplayNameKind } from '../model/CipherModels';
import { CryptoUtil } from './CryptoUtil';
import { CipherItemType } from './Constants';
import { MASTER_KEY, USER_KEY } from './Constants';
import { CredentialStore } from './CredentialStore';
import { VaultChangeNotifier } from './VaultChangeNotifier';
import { VaultImportPreview, VaultTransferCodec, VaultTransferFormat } from './VaultTransferCodec';

/** 单次操作绑定解锁会话；锁定、重新登录后不继续处理原会话的明文。 */
export class VaultTransferService {
  private sessionRevision: number = VaultViewModel.getSessionRevision();

  isCurrentSession(): boolean {
    return VaultViewModel.isSessionActive() && this.sessionRevision === VaultViewModel.getSessionRevision();
  }

  private assertSession(): void {
    if (!this.isCurrentSession()) {
      throw new Error('transfer_session_expired');
    }
  }

  async selectImport(context: common.UIAbilityContext, format: VaultTransferFormat): Promise<VaultImportPreview | null> {
    this.assertSession();
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = [format === VaultTransferFormat.JSON ? 'JSON|.json' : 'CSV|.csv'];
    const uris = await new picker.DocumentViewPicker(context).select(options);
    this.assertSession();
    if (uris.length === 0) {
      return null;
    }
    const file = await fileIo.open(uris[0], fileIo.OpenMode.READ_ONLY);
    try {
      const stat = await fileIo.stat(file.fd);
      if (stat.size <= 0 || stat.size > 20 * 1024 * 1024) {
        throw new Error('transfer_file_size');
      }
      const buffer = new ArrayBuffer(stat.size);
      const bytes = new Uint8Array(buffer);
      try {
        const count = await fileIo.read(file.fd, buffer);
        this.assertSession();
        if (count !== stat.size) {
          throw new Error('transfer_invalid_file');
        }
        const text = new util.TextDecoder('utf-8', { fatal: true }).decodeToString(bytes);
        return VaultTransferCodec.parse(text, format);
      } finally {
        bytes.fill(0);
      }
    } finally {
      await fileIo.close(file);
    }
  }

  /** 服务器接受后，即使刷新失败也不重试导入，避免重复创建。 */
  async importItems(items: Cipher[]): Promise<boolean> {
    this.assertSession();
    const vault = new VaultViewModel();
    const encrypted: Cipher[] = [];
    try {
      vault.symmetricKey = await CryptoUtil.decryptUserKey(CredentialStore.querySync(USER_KEY),
        CredentialStore.querySync(MASTER_KEY));
      for (const item of items) {
        this.assertSession();
        encrypted.push(await this.encryptCipher(item, vault.symmetricKey));
      }
      this.assertSession();
      await importCiphers(encrypted, () => this.isCurrentSession());
      // 此后服务器已经写入成功；会话失效时交由下一次登录同步，不操作新账户的数据。
      if (!this.isCurrentSession()) {
        return false;
      }
      const refreshed = await vault.syncCiphersInBackground(() => this.isCurrentSession());
      if (this.isCurrentSession()) {
        VaultChangeNotifier.setVaultReloadRequired();
      }
      return refreshed;
    } finally {
      vault.symmetricKey = '';
      vault.allCiphers = [];
      encrypted.length = 0;
    }
  }

  async exportFile(context: common.UIAbilityContext, format: VaultTransferFormat): Promise<boolean> {
    this.assertSession();
    const vault = new VaultViewModel();
    const detail = new CipherDetailViewModel();
    const items: Cipher[] = [];
    try {
      if (!await vault.loadCiphers(false)) {
        throw new Error('transfer_export_failed');
      }
      detail.symmetricKey = vault.symmetricKey;
      await detail.prepareBatchRead();
      for (const cipher of vault.allCiphers) {
        this.assertSession();
        if (cipher.deletedDate || cipher.organizationId || cipher.viewPassword === false ||
          !VaultTransferCodec.isSupported(cipher.type) ||
          (format === VaultTransferFormat.CSV && cipher.type !== CipherItemType.LOGIN && cipher.type !== CipherItemType.NOTE)) {
          continue;
        }
        if (cipher.displayNameKind === CipherDisplayNameKind.DECRYPTION_FAILED) {
          throw new Error('transfer_export_failed');
        }
        items.push(await detail.getCipherDetail(cipher));
      }
      let content = VaultTransferCodec.serialize(items, format);
      const extension = format === VaultTransferFormat.JSON ? 'json' : 'csv';
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`homowarden_export_${Date.now()}.${extension}`];
      options.fileSuffixChoices = [extension === 'json' ? 'JSON|.json' : 'CSV|.csv'];
      this.assertSession();
      const uris = await new picker.DocumentViewPicker(context).save(options);
      this.assertSession();
      if (uris.length === 0) {
        return false;
      }
      const bytes = new util.TextEncoder().encodeInto(content);
      content = '';
      try {
        this.assertSession();
        const file = await fileIo.open(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          let written = 0;
          while (written < bytes.length) {
            this.assertSession();
            const count = await fileIo.write(file.fd, bytes.slice(written).buffer);
            if (count <= 0) {
              throw new Error('transfer_export_failed');
            }
            written += count;
          }
        } finally {
          await fileIo.close(file);
        }
      } finally {
        bytes.fill(0);
      }
      return true;
    } finally {
      vault.symmetricKey = '';
      detail.clearBatchRead();
      vault.allCiphers = [];
      items.length = 0;
    }
  }

  private async encryptRecord(value: Object, key: string): Promise<Object> {
    const source = value as Record<string, string | null>;
    const fields: Record<string, string | null> = {};
    for (const name of Object.keys(source)) {
      fields[name] = await this.encryptOptionalText(source[name], key);
    }
    return fields;
  }

  private async encryptCipher(source: Cipher, key: string): Promise<Cipher> {
    const cipher = VaultTransferCodec.normalize(source);
    cipher.name = await this.encryptText(cipher.name, key);
    cipher.notes = await this.encryptOptionalText(cipher.notes, key);
    if (cipher.login) {
      cipher.login.username = await this.encryptOptionalText(cipher.login.username, key);
      cipher.login.password = await this.encryptOptionalText(cipher.login.password, key);
      cipher.login.totp = await this.encryptOptionalText(cipher.login.totp, key);
      for (const uri of cipher.login.uris) {
        uri.uriChecksum = await this.encryptText(await CryptoUtil.doSha256(uri.uri), key);
        uri.uri = await this.encryptText(uri.uri, key);
      }
    }
    if (cipher.card) {
      cipher.card = await this.encryptRecord(cipher.card, key) as CipherCard;
    }
    if (cipher.identity) {
      cipher.identity = await this.encryptRecord(cipher.identity, key) as CipherIdentity;
    }
    for (const field of cipher.fields ?? []) {
      field.name = await this.encryptText(field.name, key);
      field.value = await this.encryptText(field.value, key);
    }
    return cipher;
  }

  private async encryptText(value: string, key: string): Promise<string> {
    // 界面模型的空字段由请求边界转为 null，不能直接提交原始空字符串。
    return value === '' ? '' : await CryptoUtil.encryptField(value, key);
  }

  private async encryptOptionalText(value: string | null, key: string): Promise<string | null> {
    return value ? await this.encryptText(value, key) : null;
  }
}
