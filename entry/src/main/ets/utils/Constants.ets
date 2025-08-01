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

export const TOKEN_EXPIRE_TIME_KEY = 'token_expire_timestamp';

export const KDF_PARAM_KEY = 'kdf_param';

export const Header_Client_Name = 'web';

export const Header_Client_Version = '2025.7.0';

export const SCOPE_KEY = 'api offline_access';

export enum GrantType {
  PASSWORD = 'password',
  REFRESH = 'refresh_token'
}

export enum CipherItemType{
  LOGIN = 1,
  NOTE = 2,
  CARD = 3,
  IDENTITY = 4
}