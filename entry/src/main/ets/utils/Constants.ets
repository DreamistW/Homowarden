export enum ServerType {
  US = 0,
  EU = 1,
  SELF_HOSTED = 2
}

// 设备类型常量
export enum DeviceType {
  ANDROID = 0,
  IOS = 1,
  WINDOWS = 6,
  MACOS = 7,
  LINUX = 8,
  CHROME = 9,
  FIREFOX = 10,
  OPERA = 11,
  EDGE = 12,
  SDK = 21
}

// KDF类型常量
export enum KdfType {
  PBKDF2 = 0,
  ARGON2ID = 1
}

// 全局常量
export const DEVICE_ID_KEY = 'device_identifier';

export const SERVER_TYPE_KEY = 'server_type';

export const EMAIL_KEY = 'login_email';

export const SERVER_ADDRESS_KEY = 'server_address';

export const SERVER_BASE_URL_US = 'bitwarden.com';

export const SERVER_BASE_URL_EU = 'bitwarden.eu';

export const ACCESS_TOKEN_KEY_1 = 'access_token_1';

export const ACCESS_TOKEN_KEY_2 = 'access_token_2';

export const PRIVATE_KEY_1 = "private_key_1";

export const PRIVATE_KEY_2 = "private_key_2";

export const USER_KEY = 'user_key';

export const MASTER_KEY = 'master_key';

export const REFRESH_TOKEN_KEY = 'refresh_token';

export const TWO_FACTOR_TOKEN_KEY = 'two_factor_token';

export const TOKEN_EXPIRE_TIME_KEY = 'token_expire_timestamp';

export const KDF_PARAM_KEY = 'kdf_param';

export const Header_Client_Name = 'web';

export const Header_Client_Version = '2025.12.1';

export const SCOPE_KEY = 'api offline_access';

export const LOGIN_STATUS_KEY = 'login_status';

export const PRIVACY_AGREED_KEY = 'privacy_agreed';

export const SAVE_EMAIL = 'save_email';

export const BIOMETRIC_AUTH = 'biometric_auth';

export const NEED_RELOAD_CIPHERS = 'need_reload_ciphers';

export const BACKGROUND_TIMESTAMP = 'background_timestamp';

export const AUTO_LOCK = 'auto_lock';

export enum GrantType {
  PASSWORD = 'password',
  REFRESH = 'refresh_token'
}

export enum CipherItemType {
  LOGIN = 1,
  NOTE = 2,
  CARD = 3,
  IDENTITY = 4
}

export enum CipherFieldType {
  TEXT = 0,
  HIDE = 1,
  BOOL = 2
}

export enum DBTableName {
  MAIN = 'ciphers',
  LOGINS = 'cipher_logins',
  CARDS = 'cipher_cards',
  IDENTITIES = 'cipher_identities',
  FIELDS = 'cipher_fields',
  NOTES = 'cipher_secure_notes'
}

export enum FilterType {
  ALL = 0,
  LOGINS = 1,
  NOTES = 2,
  CARDS = 3,
  IDENTITIES = 4,
  FAVORITE = 5,
  DELETED = 6
}

export enum IdentityTitleType {
  NONE = 0,
  MR = 1,
  MRS = 2,
  MISS = 3,
  MX = 4,
  DR = 5
}

export enum CardBrandType {
  NONE = 0,
  VISA = 1,
  MASTER = 2,
  AME = 3,
  DISCOVER = 4,
  DINERS = 5,
  JCB = 6,
  MAESTRO = 7,
  UNIONPAY = 8,
  RUPAY = 9,
  OTHER = 10
}