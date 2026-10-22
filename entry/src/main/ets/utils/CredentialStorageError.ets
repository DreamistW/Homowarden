import { BusinessError } from '@kit.BasicServicesKit';

export enum CredentialStorageFailure {
  PREFERENCES = 'preferences',
  KEY_MISSING = 'key-missing',
  KEY_READ = 'key-read',
  KEY_INVALID = 'key-invalid',
  KEY_CREATE = 'key-create',
  KEY_VERIFY = 'key-verify',
  KEY_REMOVE = 'key-remove',
  DATABASE_CHECK = 'database-check',
  DATABASE_OPEN = 'database-open',
  DATABASE_INITIALIZE = 'database-initialize',
  DATABASE_DELETE = 'database-delete',
  LEGACY_MIGRATION = 'legacy-migration'
}

/** 只携带固定原因和系统错误码，避免把凭据或数据库原文显示到界面。 */
export class CredentialStorageError extends Error {
  reason: CredentialStorageFailure;
  code: number;

  constructor(reason: CredentialStorageFailure, code: number = 0) {
    super(`Credential storage failed: reason=${reason}, code=${code}`);
    this.reason = reason;
    this.code = code;
  }

  static wrap(error: Error, fallback: CredentialStorageFailure): CredentialStorageError {
    if (error instanceof CredentialStorageError) {
      return error;
    }
    const code = (error as BusinessError).code;
    return new CredentialStorageError(fallback, Number.isFinite(code) ? code : 0);
  }

  static description(reason: CredentialStorageFailure): Resource {
    switch (reason) {
      case CredentialStorageFailure.KEY_MISSING:
        return $r('app.string.storage_reason_key_missing');
      case CredentialStorageFailure.KEY_READ:
        return $r('app.string.storage_reason_key_read');
      case CredentialStorageFailure.KEY_INVALID:
        return $r('app.string.storage_reason_key_invalid');
      case CredentialStorageFailure.KEY_CREATE:
      case CredentialStorageFailure.KEY_VERIFY:
        return $r('app.string.storage_reason_key_create');
      case CredentialStorageFailure.KEY_REMOVE:
        return $r('app.string.storage_reason_key_remove');
      case CredentialStorageFailure.DATABASE_CHECK:
        return $r('app.string.storage_reason_database_check');
      case CredentialStorageFailure.DATABASE_OPEN:
        return $r('app.string.storage_reason_database_open');
      case CredentialStorageFailure.DATABASE_INITIALIZE:
        return $r('app.string.storage_reason_database_initialize');
      case CredentialStorageFailure.DATABASE_DELETE:
        return $r('app.string.storage_reason_database_delete');
      case CredentialStorageFailure.LEGACY_MIGRATION:
        return $r('app.string.storage_reason_legacy_migration');
      default:
        return $r('app.string.storage_reason_preferences');
    }
  }
}
