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

// 全局Key常量
export const DEVICE_ID_KEY = 'device_identifier';
export const SERVER_TYPE_KEY = 'server_type';
export const SERVER_ADDRESS_KEY = 'server_address';
export const SERVER_BASE_URL_US = 'bitwarden.com';
export const SERVER_BASE_URL_EU = 'bitwarden.eu';


