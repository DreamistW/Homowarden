import { CipherFieldType, CipherItemType } from '../utils/Constants';

/** 新建密码项时由密码库传入的密钥和已选类型。 */
export interface AddCipherParams {
  symmetricKey: string;
  type: CipherItemType;
}

/** 密码项名称的显示来源，用于区分用户数据与本地状态文案 */
export enum CipherDisplayNameKind {
  USER_VALUE = 0,
  DECRYPTION_FAILED = 1
}

/** 密码项副标题的显示来源，用于按当前语言解析非用户文案 */
export enum CipherDisplaySubtitleKind {
  USER_VALUE = 0,
  DECRYPTION_FAILED = 1,
  LOGIN = 2,
  NOTE = 3,
  CARD = 4,
  IDENTITY = 5,
  UNKNOWN = 6
}

/**
 * 密码项（Cipher）数据模型
 */
export interface Cipher {
  id: string; // 密码项ID
  type: CipherItemType; // 密码项类型（1=登录，2=安全笔记，3=卡片，4=身份信息）
  name: string; // 名称
  favorite: boolean; // 是否收藏
  edit: boolean; // 是否可编辑
  viewPassword?: boolean; // 是否可查看密码
  folderId: string | null; // 文件夹ID
  organizationId: string | null; // 组织ID
  creationDate: string; // 创建时间
  revisionDate: string; // 最后修改时间
  lastKnownRevisionDate?: string | null; // 官方更新请求使用的并发版本
  deletedDate: string | null; // 删除时间
  archivedDate?: string | null; // 归档时间
  notes: string | null; // 备注
  login: CipherLogin | null; // 登录信息（type=1时）
  card: CipherCard | null; // 卡片信息（type=3时）
  identity: CipherIdentity | null; // 身份信息（type=4时）
  secureNote: CipherSecureNote | null; // 安全笔记（type=2时）
  sshKey?: CipherSshKey | null; // SSH Key（新版官方类型）
  bankAccount?: CipherBankAccount | null; // 银行账户（新版官方类型）
  driversLicense?: CipherDriversLicense | null; // 驾照（新版官方类型）
  passport?: CipherPassport | null; // 护照（新版官方类型）
  fields?: CipherField[]; // 自定义字段
  collectionIds?: string[]; // 所属集合ID
  passwordHistory?: CipherPasswordHistory[] | null; // 密码历史
  attachments?: CipherAttachment[] | null; // 响应中的附件
  attachments2?: Record<string, CipherAttachmentRequest> | null; // 官方请求中的附件映射
  key?: string | null; // 组织/条目加密 key
  encryptedFor?: string | null; // 被加密目标用户
  reprompt: number; // 是否需要验证主密码才能查看
  subtitle?: string; // 副标题，显示在密码库界面
  // 以下字段只承载列表显示语义，不属于服务端 Cipher 数据协议
  displayNameKind?: CipherDisplayNameKind;
  displaySubtitleKind?: CipherDisplaySubtitleKind;
  // 保留姓名分量，以便语言切换后按目标语言顺序重新组合
  identityFirstName?: string;
  identityLastName?: string;
  // 仅记录登录项是否配置 TOTP，列表不保留 TOTP 密钥明文
  hasTotp?: boolean;
}

/**
 * 登录信息结构
 */
export interface CipherLogin {
  username: string | null; // 用户名
  password: string | null; // 密码
  passwordRevisionDate: string | null; // 密码更新时间
  totp: string | null; // TOTP密钥
  uris: CipherUri[]; // 关联网址
  uri?: string | null; // 旧版单 URI 字段
  autofillOnPageLoad?: boolean | null; // 页面加载时自动填充
  fido2Credentials?: CipherFido2Credential[] | null; // FIDO2 凭据
}

/**
 * 卡片信息结构
 */
export interface CipherCard {
  cardholderName: string | null; // 持卡人姓名
  brand: string | null; // 品牌
  number: string | null; // 卡号
  expMonth: string | null; // 有效期月
  expYear: string | null; // 有效期年
  code: string | null; // 安全码
}

/**
 * 身份信息结构
 */
export interface CipherIdentity {
  address1: string | null;
  address2: string | null;
  address3: string | null;
  city: string | null;
  company: string | null;
  country: string | null;
  email: string | null;
  firstName: string | null;
  lastName: string | null;
  licenseNumber: string | null;
  middleName: string | null;
  passportNumber: string | null;
  phone: string | null;
  postalCode: string | null;
  ssn: string | null;
  state: string | null;
  title: string | null;
  username: string | null;
}

/**
 * 安全笔记结构
 */
export interface CipherSecureNote {
  type: CipherFieldType; // 类型
}

/**
 * 自定义字段结构
 */
export interface CipherField {
  name: string; // 字段名
  value: string; // 字段值
  type: CipherFieldType; // 字段类型（0为文本，1为隐藏，2为复选框）
  linkedId?: number | null; // 官方字段联动 ID
  // 仅作为 ForEach 行 key 使用的本地内存标识，不参与加解密、数据库写入与服务端序列化
  itemId?: string;
}

/**
 * URI结构
 */
export interface CipherUri {
  uri: string;
  match?: number | null;
  uriChecksum: string;
}

export interface CipherPasswordHistory {
  password: string;
  lastUsedDate: string;
}

export interface CipherAttachment {
  id?: string | null;
  fileName?: string | null;
  size?: number | null;
  sizeName?: string | null;
  url?: string | null;
  key?: string | null;
}

export interface CipherAttachmentRequest {
  id?: string | null;
  fileName?: string | null;
  key?: string | null;
}

export interface CipherSshKey {
  publicKey: string | null;
  privateKey: string | null;
  keyFingerprint: string | null;
}

export interface CipherBankAccount {
  bankName: string | null;
  nameOnAccount: string | null;
  accountType: string | null;
  accountNumber: string | null;
  routingNumber: string | null;
  branchNumber: string | null;
  pin: string | null;
  swiftCode: string | null;
  iban: string | null;
  bankContactPhone: string | null;
}

export interface CipherDriversLicense {
  firstName: string | null;
  middleName: string | null;
  lastName: string | null;
  licenseNumber: string | null;
  dateOfBirth: string | null;
  issuingCountry: string | null;
  issuingAuthority: string | null;
  issuingState: string | null;
  issueDate: string | null;
  expirationDate: string | null;
  licenseClass: string | null;
}

export interface CipherPassport {
  surname: string | null;
  givenName: string | null;
  dateOfBirth: string | null;
  birthPlace: string | null;
  sex: string | null;
  nationality: string | null;
  passportNumber: string | null;
  passportType: string | null;
  issuingCountry: string | null;
  issuingAuthority: string | null;
  issueDate: string | null;
  expirationDate: string | null;
  nationalIdentificationNumber: string | null;
}

export interface CipherFido2Credential {
  credentialId: string;
  keyType?: string;
  keyAlgorithm?: string;
  keyCurve?: string;
  keyValue: string;
  rpId: string;
  rpName?: string | null;
  userHandle?: string | null;
  userName?: string | null;
  userDisplayName?: string | null;
  counter: string;
  discoverable: string;
  creationDate: string;
}

/** 请求模型区分未填写（null）和有效密文；不改变界面模型的空文本。 */
export interface CipherUriJsonRequest {
  uri: string | null;
  uriChecksum: string | null;
  match?: number | null;
}

export interface CipherPasswordHistoryJsonRequest {
  password: string | null;
  lastUsedDate: string;
}

export interface CipherLoginJsonRequest {
  username: string | null;
  password: string | null;
  totp: string | null;
  passwordRevisionDate: string | null;
  uris: CipherUriJsonRequest[];
  uri: string | null;
  autofillOnPageLoad?: boolean | null;
  fido2Credentials: CipherFido2CredentialJsonRequest[] | null;
}

export interface CipherFido2CredentialJsonRequest {
  credentialId: string | null;
  keyType: string | null;
  keyAlgorithm: string | null;
  keyCurve: string | null;
  keyValue: string | null;
  rpId: string | null;
  rpName: string | null;
  userHandle: string | null;
  userName: string | null;
  userDisplayName: string | null;
  counter: string | null;
  discoverable: string | null;
  creationDate: string;
}

export interface CipherJsonRequest {
  notes: string | null;
  attachments2: Record<string, CipherAttachmentRequest> | null;
  reprompt: number;
  passwordHistory: CipherPasswordHistoryJsonRequest[] | null;
  lastKnownRevisionDate: string | null;
  type: CipherItemType;
  login: CipherLoginJsonRequest | null;
  secureNote: CipherSecureNote | null;
  sshKey: CipherSshKey | null;
  bankAccount: CipherBankAccount | null;
  driversLicense: CipherDriversLicense | null;
  passport: CipherPassport | null;
  folderId: string | null;
  organizationId: string | null;
  identity: CipherIdentity | null;
  name: string | null;
  fields: CipherFieldJsonRequest[] | null;
  favorite: boolean;
  card: CipherCard | null;
  key: string | null;
  archivedDate: string | null;
  encryptedFor: string | null;
}

/** 加密请求的空字段使用 null；界面中的空文本仍使用字符串。 */
export interface CipherFieldJsonRequest {
  name: string | null;
  value: string | null;
  type: CipherFieldType;
  linkedId?: number | null;
}

export interface CipherPartialRequest {
  folderId: string | null;
  favorite: boolean;
}

export interface CreateCipherInOrganizationRequest {
  Cipher: CipherJsonRequest;
  CollectionIds: string[];
}

export interface VaultSyncResponse {
  folders?: Object[] | null;
  collections?: Object[] | null;
  profile?: Object | null;
  Profile?: Object | null;
  ciphers?: Cipher[] | null;
  policies?: Object[] | null;
  policiesNew?: Object[] | null;
  domains?: Object | null;
  Domains?: Object | null;
  sends?: Object[] | null;
  userDecryption?: Object | null;
}

export enum CipherDetailMode {
  VIEW = 0,
  EDIT = 1
}

/*
 * 从密码库跳转到详情页的参数
 */
export interface CipherDetailParams {
  cipher: Cipher;
  symmetricKey: string;
  initialMode?: CipherDetailMode;
}
