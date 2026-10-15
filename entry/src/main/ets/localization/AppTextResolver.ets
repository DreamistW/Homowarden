import { AppText, AppTextKey } from './AppText';

/** 将业务层文案键解析为 ArkUI 资源 */
export class AppTextResolver {
  static resource(text: AppText): Resource {
    switch (text.key) {
      case AppTextKey.RATE_LIMITED:
        return $r('app.string.login_error_rate_limited');
      case AppTextKey.EMAIL_UNVERIFIED:
        return $r('app.string.login_error_email_unverified');
      case AppTextKey.ACCOUNT_DISABLED:
        return $r('app.string.login_error_account_disabled');
      case AppTextKey.SSO_REQUIRED:
        return $r('app.string.login_error_sso_required');
      case AppTextKey.ACCOUNT_MIGRATION_REQUIRED:
        return $r('app.string.login_error_account_migration_required');
      case AppTextKey.CLIENT_VERSION_UNSUPPORTED:
        return $r('app.string.login_error_client_version');
      case AppTextKey.ACCESS_RESTRICTED:
        return $r('app.string.login_error_access_restricted');
      case AppTextKey.KDF_RESOURCES_UNAVAILABLE:
        return $r('app.string.login_error_kdf_resources');

      case AppTextKey.NETWORK_ERROR:
        return $r('app.string.error_network');
      case AppTextKey.TIMEOUT_ERROR:
        return $r('app.string.error_timeout');
      case AppTextKey.AUTH_EXPIRED:
        return $r('app.string.error_auth_expired');
      case AppTextKey.INVALID_CREDENTIALS:
        return $r('app.string.error_invalid_credentials');
      case AppTextKey.VALIDATION_ERROR:
        return $r('app.string.error_validation');
      case AppTextKey.STORAGE_ERROR:
        return $r('app.string.error_storage');
      case AppTextKey.ENCRYPTION_ERROR:
        return $r('app.string.error_encryption');
      case AppTextKey.PERMISSION_ERROR:
        return $r('app.string.error_permission');
      case AppTextKey.CANCELLED:
        return $r('app.string.error_cancelled');
      case AppTextKey.LOAD_FAILED:
        return $r('app.string.error_load_failed');
      case AppTextKey.SAVE_FAILED:
        return $r('app.string.error_save_failed');
      case AppTextKey.DELETE_FAILED:
        return $r('app.string.error_delete_failed');
      case AppTextKey.SHARE_FAILED:
        return $r('app.string.error_share_failed');
      case AppTextKey.EMAIL_REQUIRED:
        return $r('app.string.login_error_email_required');
      case AppTextKey.PASSWORD_REQUIRED:
        return $r('app.string.login_error_password_required');
      case AppTextKey.SERVER_REQUIRED:
        return $r('app.string.login_error_server_required');
      case AppTextKey.PRELOGIN_FAILED:
        return $r('app.string.login_error_prelogin_failed');
      case AppTextKey.KDF_UNSUPPORTED:
        return $r('app.string.error_kdf_unsupported');
      case AppTextKey.MASTER_KEY_FAILED:
        return $r('app.string.error_master_key_failed');
      case AppTextKey.LOGIN_FAILED:
        return $r('app.string.login_error_failed');
      case AppTextKey.LOGIN_SUCCESS:
        return $r('app.string.login_success');
      case AppTextKey.TWO_FACTOR_UNSUPPORTED:
        return $r('app.string.login_error_two_factor_unsupported');
      case AppTextKey.PASSKEY_FAILED:
        return $r('app.string.login_error_passkey_failed');
      case AppTextKey.VERIFICATION_REQUIRED:
        return $r('app.string.login_error_verification_required');
      case AppTextKey.CODE_REQUIRED:
        return $r('app.string.login_error_code_required');
      case AppTextKey.CODE_INVALID:
        return $r('app.string.login_error_code_invalid');
      case AppTextKey.DEVICE_VERIFICATION_FAILED:
        return $r('app.string.login_error_device_verification_failed');
      case AppTextKey.PASSWORD_RESET_REQUIRED:
        return $r('app.string.login_error_password_reset_required');
      case AppTextKey.DECRYPTION_UNSUPPORTED:
        return $r('app.string.login_error_decryption_unsupported');
      case AppTextKey.CODE_SEND_FAILED:
        return $r('app.string.login_error_code_send_failed');
      case AppTextKey.CODE_SENT:
        return $r('app.string.login_code_sent');
      case AppTextKey.MASTER_PASSWORD_REQUIRED:
        return $r('app.string.unlock_enter_master_password');
      case AppTextKey.MASTER_PASSWORD_WRONG:
        return $r('app.string.unlock_wrong_password');
      case AppTextKey.PARAMETERS_FAILED:
        return $r('app.string.unlock_parameters_failed');
      case AppTextKey.VERIFICATION_FAILED:
        return $r('app.string.unlock_verification_failed');
      default:
        return $r('app.string.error_unknown');
    }
  }
}
