/** 可跨 ViewModel 和 UI 层传递的本地化文案键 */
export enum AppTextKey {
  UNKNOWN_ERROR = 'error_unknown',
  NETWORK_ERROR = 'error_network',
  TIMEOUT_ERROR = 'error_timeout',
  AUTH_EXPIRED = 'error_auth_expired',
  INVALID_CREDENTIALS = 'error_invalid_credentials',
  VALIDATION_ERROR = 'error_validation',
  STORAGE_ERROR = 'error_storage',
  ENCRYPTION_ERROR = 'error_encryption',
  PERMISSION_ERROR = 'error_permission',
  CANCELLED = 'error_cancelled',
  LOAD_FAILED = 'error_load_failed',
  SAVE_FAILED = 'error_save_failed',
  DELETE_FAILED = 'error_delete_failed',
  SHARE_FAILED = 'error_share_failed',
  EMAIL_REQUIRED = 'login_error_email_required',
  PASSWORD_REQUIRED = 'login_error_password_required',
  SERVER_REQUIRED = 'login_error_server_required',
  PRELOGIN_FAILED = 'login_error_prelogin_failed',
  KDF_UNSUPPORTED = 'error_kdf_unsupported',
  MASTER_KEY_FAILED = 'error_master_key_failed',
  LOGIN_FAILED = 'login_error_failed',
  LOGIN_SUCCESS = 'login_success',
  TWO_FACTOR_UNSUPPORTED = 'login_error_two_factor_unsupported',
  PASSKEY_FAILED = 'login_error_passkey_failed',
  VERIFICATION_REQUIRED = 'login_error_verification_required',
  CODE_REQUIRED = 'login_error_code_required',
  CODE_INVALID = 'login_error_code_invalid',
  DEVICE_VERIFICATION_FAILED = 'login_error_device_verification_failed',
  PASSWORD_RESET_REQUIRED = 'login_error_password_reset_required',
  DECRYPTION_UNSUPPORTED = 'login_error_decryption_unsupported',
  CODE_SEND_FAILED = 'login_error_code_send_failed',
  CODE_SENT = 'login_code_sent',
  MASTER_PASSWORD_REQUIRED = 'unlock_enter_master_password',
  MASTER_PASSWORD_WRONG = 'unlock_wrong_password',
  PARAMETERS_FAILED = 'unlock_parameters_failed',
  VERIFICATION_FAILED = 'unlock_verification_failed'
}

/** 以稳定键表示业务文案，避免在 ViewModel 中固化具体语言 */
export class AppText {
  key: AppTextKey;

  constructor(key: AppTextKey) {
    this.key = key;
  }
}

/** UI 消息的展示语义 */
export enum UiMessageKind {
  ERROR = 0,
  SUCCESS = 1,
  INFO = 2
}

/** 携带消息类型及本地化文案的 UI 消息 */
export class UiMessage {
  kind: UiMessageKind;
  text: AppText;

  constructor(kind: UiMessageKind, text: AppText) {
    this.kind = kind;
    this.text = text;
  }
}
