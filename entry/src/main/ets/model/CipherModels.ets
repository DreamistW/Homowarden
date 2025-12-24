import { CipherFieldType, CipherItemType } from '../utils/Constants';

/**
 * 密码项（Cipher）数据模型
 */
export interface Cipher {
  id: string; // 密码项ID
  type: CipherItemType; // 密码项类型（1=登录，2=安全笔记，3=卡片，4=身份信息）
  name: string; // 名称
  favorite: boolean; // 是否收藏
  edit: boolean; // 是否可编辑
  folderId: string | null; // 文件夹ID
  organizationId: string | null; // 组织ID
  creationDate: string; // 创建时间
  revisionDate: string; // 最后修改时间
  deletedDate: string | null; // 删除时间
  notes: string | null; // 备注
  login: CipherLogin | null; // 登录信息（type=1时）
  card: CipherCard | null; // 卡片信息（type=3时）
  identity: CipherIdentity | null; // 身份信息（type=4时）
  secureNote: CipherSecureNote | null; // 安全笔记（type=2时）
  fields?: CipherField[]; // 自定义字段
  collectionIds?: string[]; // 所属集合ID
  reprompt: number; // 是否需要验证主密码才能查看
  subtitle?: string; // 副标题，显示在密码库界面
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
}

/**
 * URI结构
 */
export interface CipherUri {
  uri: string;
  match?: number | null;
  uriChecksum: string;
}

/*
 * 从密码库跳转到详情页的参数
 */
export interface CipherDetailParams {
  cipher: Cipher;
  symmetricKey: string;
}