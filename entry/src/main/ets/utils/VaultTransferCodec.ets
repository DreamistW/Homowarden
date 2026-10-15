import { Cipher, CipherCard, CipherField, CipherIdentity, CipherLogin, CipherUri } from '../model/CipherModels';
import { CipherItemType } from './Constants';

export enum VaultTransferFormat {
  JSON = 0,
  CSV = 1
}

export class VaultImportPreview {
  items: Cipher[] = [];
  skipped: number = 0;
}

interface VaultJsonDocument {
  encrypted?: boolean;
  passwordProtected?: boolean;
  items?: Cipher[];
}

interface VaultExportItem {
  id: string;
  organizationId: null;
  folderId: null;
  type: CipherItemType;
  reprompt: number;
  name: string;
  notes: string | null;
  favorite: boolean;
  fields: CipherField[];
  login: VaultExportLogin | null;
  secureNote: Object | null;
  card: CipherCard | null;
  identity: CipherIdentity | null;
  creationDate: string;
  revisionDate: string;
}

interface VaultExportUri {
  uri: string;
  match: number | null;
}

interface VaultExportLogin {
  username: string | null;
  password: string | null;
  totp: string | null;
  uris: VaultExportUri[];
}

interface VaultExportDocument {
  encrypted: boolean;
  folders: Object[];
  items: VaultExportItem[];
}

/** Bitwarden 明文格式边界；只保留本应用可读取的字段，不信任文件中的 ID、密钥和归属。 */
export class VaultTransferCodec {
  private static readonly CSV_HEADERS: string[] = [
    'folder', 'favorite', 'type', 'name', 'notes', 'fields', 'reprompt',
    'login_uri', 'login_username', 'login_password', 'login_totp'
  ];

  static parse(content: string, format: VaultTransferFormat): VaultImportPreview {
    const text = content.replace(/^\uFEFF/, '');
    if (format === VaultTransferFormat.CSV) {
      return VaultTransferCodec.parseCsv(text);
    }
    const document: VaultJsonDocument = JSON.parse(text);
    if (!document || typeof document !== 'object' || Array.isArray(document)) {
      throw new Error('transfer_invalid_file');
    }
    if (document.encrypted === true || document.passwordProtected === true) {
      throw new Error('transfer_encrypted_file');
    }
    if (!Array.isArray(document.items) || document.items.length > 10000) {
      throw new Error('transfer_invalid_file');
    }
    const preview = new VaultImportPreview();
    for (const source of document.items) {
      if (!source || typeof source !== 'object' || !VaultTransferCodec.isSupported(source.type)) {
        preview.skipped++;
        continue;
      }
      // 已支持类型的结构损坏时终止预览，避免把损坏数据当作成功导入。
      preview.items.push(VaultTransferCodec.normalize(source));
    }
    return preview;
  }

  static isSupported(type: number): boolean {
    return Number.isInteger(type) && type >= CipherItemType.LOGIN && type <= CipherItemType.IDENTITY;
  }

  static normalize(source: Cipher): Cipher {
    if (typeof source.name !== 'string' || !source.name.trim()) {
      throw new Error('transfer_invalid_file');
    }
    const result: Cipher = {
      id: '', type: source.type, name: source.name, notes: VaultTransferCodec.text(source.notes),
      favorite: source.favorite === true, edit: true, folderId: null, organizationId: null,
      creationDate: '', revisionDate: '', deletedDate: null, reprompt: source.reprompt === 1 ? 1 : 0,
      login: null, card: null, identity: null, secureNote: null, fields: []
    };
    if (source.fields !== null && source.fields !== undefined && !Array.isArray(source.fields)) {
      throw new Error('transfer_invalid_file');
    }
    for (const field of source.fields ?? []) {
      if (field && (field.type === 0 || field.type === 1 || field.type === 2)) {
        result.fields!.push({
          name: VaultTransferCodec.text(field.name) ?? '', value: VaultTransferCodec.text(field.value) ?? '',
          type: field.type
        });
      }
    }
    switch (source.type) {
      case CipherItemType.LOGIN:
        if (!source.login || typeof source.login !== 'object' || Array.isArray(source.login)) {
          throw new Error('transfer_invalid_file');
        }
        result.login = VaultTransferCodec.login(source.login);
        break;
      case CipherItemType.NOTE:
        result.secureNote = { type: 0 };
        break;
      case CipherItemType.CARD:
        if (!source.card || typeof source.card !== 'object' || Array.isArray(source.card)) {
          throw new Error('transfer_invalid_file');
        }
        result.card = {
          cardholderName: VaultTransferCodec.cardText(source.card.cardholderName),
          brand: VaultTransferCodec.cardText(source.card.brand), number: VaultTransferCodec.cardText(source.card.number),
          expMonth: VaultTransferCodec.cardText(source.card.expMonth),
          expYear: VaultTransferCodec.cardText(source.card.expYear), code: VaultTransferCodec.cardText(source.card.code)
        };
        break;
      case CipherItemType.IDENTITY:
        if (!source.identity || typeof source.identity !== 'object' || Array.isArray(source.identity)) {
          throw new Error('transfer_invalid_file');
        }
        result.identity = VaultTransferCodec.identity(source.identity);
        break;
    }
    return result;
  }

  private static text(value: string | null | undefined): string | null {
    if (value === undefined || value === null) {
      return null;
    }
    if (typeof value !== 'string') {
      throw new Error('transfer_invalid_file');
    }
    return value;
  }

  private static cardText(value: string | null | undefined): string | null {
    // 卡片可选字段的空值必须为 null，不能把空串作为加密字段提交给 Bitwarden。
    return VaultTransferCodec.text(value) || null;
  }

  private static login(login: CipherLogin): CipherLogin {
    if (login.uris !== null && login.uris !== undefined && !Array.isArray(login.uris)) {
      throw new Error('transfer_invalid_file');
    }
    const uris: CipherUri[] = [];
    for (const uri of login.uris ?? []) {
      if (!uri || typeof uri !== 'object') {
        throw new Error('transfer_invalid_file');
      }
      uris.push({
        uri: VaultTransferCodec.text(uri.uri) ?? '', uriChecksum: '',
        match: Number.isInteger(uri.match) && (uri.match as number) >= 0 && (uri.match as number) <= 5 ? uri.match : null
      });
    }
    if (uris.length === 0 && login.uri) {
      uris.push({ uri: VaultTransferCodec.text(login.uri) ?? '', uriChecksum: '', match: null });
    }
    return {
      username: VaultTransferCodec.text(login.username), password: VaultTransferCodec.text(login.password),
      totp: VaultTransferCodec.text(login.totp), passwordRevisionDate: null, uris: uris
    };
  }

  private static identity(identity: CipherIdentity): CipherIdentity {
    return {
      title: VaultTransferCodec.text(identity.title), firstName: VaultTransferCodec.text(identity.firstName),
      middleName: VaultTransferCodec.text(identity.middleName), lastName: VaultTransferCodec.text(identity.lastName),
      address1: VaultTransferCodec.text(identity.address1), address2: VaultTransferCodec.text(identity.address2),
      address3: VaultTransferCodec.text(identity.address3), city: VaultTransferCodec.text(identity.city),
      state: VaultTransferCodec.text(identity.state), postalCode: VaultTransferCodec.text(identity.postalCode),
      country: VaultTransferCodec.text(identity.country), company: VaultTransferCodec.text(identity.company),
      email: VaultTransferCodec.text(identity.email), phone: VaultTransferCodec.text(identity.phone),
      ssn: VaultTransferCodec.text(identity.ssn), username: VaultTransferCodec.text(identity.username),
      passportNumber: VaultTransferCodec.text(identity.passportNumber),
      licenseNumber: VaultTransferCodec.text(identity.licenseNumber)
    };
  }

  static serialize(items: Cipher[], format: VaultTransferFormat): string {
    if (format === VaultTransferFormat.CSV) {
      const rows: string[][] = [VaultTransferCodec.CSV_HEADERS];
      for (const item of items) {
        if (item.type !== CipherItemType.LOGIN && item.type !== CipherItemType.NOTE) {
          continue;
        }
        const fields = (item.fields ?? []).map((field: CipherField) => `${field.name}: ${field.value}`).join('\n');
        // Bitwarden 在 login_uri 单元格中再使用一层 CSV 编码表达多个网址。
        const uris = (item.login?.uris ?? []).map((uri: CipherUri) => VaultTransferCodec.quote(uri.uri)).join(',');
        rows.push(['', item.favorite ? '1' : '', item.type === CipherItemType.LOGIN ? 'login' : 'note',
          item.name, item.notes ?? '', fields, item.reprompt.toString(), uris,
          item.login?.username ?? '', item.login?.password ?? '', item.login?.totp ?? '']);
      }
      return rows.map((row: string[]) => row.map((value: string) => VaultTransferCodec.quote(value)).join(','))
        .join('\r\n');
    }
    const exported: VaultExportItem[] = items.map((item: Cipher): VaultExportItem => {
      const normalized = VaultTransferCodec.normalize(item);
      return {
        id: item.id, organizationId: null, folderId: null, type: normalized.type, reprompt: normalized.reprompt,
        name: normalized.name, notes: normalized.notes, favorite: normalized.favorite, fields: normalized.fields ?? [],
        login: normalized.login ? {
          username: normalized.login.username, password: normalized.login.password, totp: normalized.login.totp,
          uris: normalized.login.uris.map((uri: CipherUri): VaultExportUri => ({ uri: uri.uri, match: uri.match ?? null }))
        } : null,
        secureNote: normalized.secureNote, card: normalized.card, identity: normalized.identity,
        creationDate: item.creationDate, revisionDate: item.revisionDate
      };
    });
    const document: VaultExportDocument = { encrypted: false, folders: [], items: exported };
    return JSON.stringify(document, null, 2);
  }

  private static quote(value: string): string {
    return /[",\r\n]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value;
  }

  /** 支持 UTF-8 BOM、CRLF、双引号转义和带换行的单元格。 */
  static csvRows(text: string): string[][] {
    const rows: string[][] = [];
    let row: string[] = [];
    let cell = '';
    let quoted = false;
    let closed = false;
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      if (quoted) {
        if (char === '"') {
          if (text[i + 1] === '"') {
            cell += '"';
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          cell += char;
        }
      } else if (char === ',') {
        row.push(cell);
        cell = '';
        closed = false;
      } else if (char === '\r' || char === '\n') {
        row.push(cell);
        rows.push(row);
        if (char === '\r' && text[i + 1] === '\n') {
          i++;
        }
        row = [];
        cell = '';
        closed = false;
      } else if (char === '"' && !cell && !closed) {
        quoted = true;
      } else {
        if (closed || char === '"') {
          throw new Error('transfer_invalid_file');
        }
        cell += char;
      }
      if (rows.length > 10001) {
        throw new Error('transfer_invalid_file');
      }
    }
    if (quoted) {
      throw new Error('transfer_invalid_file');
    }
    if (cell || row.length || closed) {
      row.push(cell);
      rows.push(row);
    }
    return rows;
  }

  private static parseCsv(text: string): VaultImportPreview {
    const rows = VaultTransferCodec.csvRows(text);
    const headers = rows.shift() ?? [];
    if (headers.indexOf('name') < 0 || headers.indexOf('type') < 0 || new Set(headers).size !== headers.length) {
      throw new Error('transfer_invalid_file');
    }
    const preview = new VaultImportPreview();
    for (const row of rows) {
      if (row.every((value: string) => value === '')) {
        continue;
      }
      if (row.length > headers.length) {
        throw new Error('transfer_invalid_file');
      }
      const values: Record<string, string> = {};
      headers.forEach((header: string, i: number) => { values[header] = row[i] ?? ''; });
      if (values['type'] !== 'login' && values['type'] !== 'note') {
        preview.skipped++;
        continue;
      }
      const source: Cipher = {
        id: '', type: values['type'] === 'note' ? CipherItemType.NOTE : CipherItemType.LOGIN,
        name: values['name'], notes: values['notes'] ?? '', favorite: values['favorite'] === '1', edit: true,
        folderId: null, organizationId: null, creationDate: '', revisionDate: '', deletedDate: null,
        reprompt: values['reprompt'] === '1' ? 1 : 0, login: null, card: null, identity: null,
        secureNote: null, fields: []
      };
      if (source.type === CipherItemType.LOGIN) {
        const uriValue = values['login_uri'] ?? values['uri'] ?? '';
        const uris = uriValue ? VaultTransferCodec.csvRows(uriValue) : [];
        if (uris.length > 1) {
          throw new Error('transfer_invalid_file');
        }
        source.login = {
          username: values['login_username'] ?? values['username'] ?? '',
          password: values['login_password'] ?? values['password'] ?? '',
          totp: values['login_totp'] ?? values['totp'] ?? '', passwordRevisionDate: null,
          uris: (uris[0] ?? []).map((uri: string): CipherUri => ({ uri: uri, match: null, uriChecksum: '' }))
        };
      }
      for (const line of (values['fields'] ?? '').split(/\r\n|\n|\r/)) {
        const index = line.lastIndexOf(': ');
        if (index >= 0) {
          source.fields!.push({ name: line.substring(0, index), value: line.substring(index + 2), type: 0 });
        }
      }
      preview.items.push(VaultTransferCodec.normalize(source));
    }
    return preview;
  }
}
