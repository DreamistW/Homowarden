import { CredentialStore } from './CredentialStore';
import { ACCESS_TOKEN_KEY, GrantType, Header_Client_Name, REFRESH_TOKEN_KEY, TOKEN_EXPIRE_TIME_KEY } from './Constants';
import { refreshToken } from '../network/AuthApi';
import { CredentialSnapshot } from './CredentialDatabase';

/** 同一凭据版本只发起一次刷新；退出或切换账号后丢弃旧刷新结果。 */
export class SessionTokenUtil {
  private static pending: Promise<string> | null = null;
  private static pendingRevision: number = -1;

  static async getAccessToken(): Promise<string> {
    await CredentialStore.ready();
    const snapshot = CredentialStore.sessionSync();
    const expiresAt = Number(snapshot.values[TOKEN_EXPIRE_TIME_KEY] ?? '');
    const token = snapshot.values[ACCESS_TOKEN_KEY] ?? '';
    if (token && Number.isFinite(expiresAt) && expiresAt > Math.floor(Date.now() / 1000) + 120) {
      return token;
    }
    if (SessionTokenUtil.pending && SessionTokenUtil.pendingRevision === snapshot.revision) {
      return SessionTokenUtil.pending;
    }
    const request = SessionTokenUtil.refresh(snapshot);
    SessionTokenUtil.pending = request;
    SessionTokenUtil.pendingRevision = snapshot.revision;
    try {
      return await request;
    } finally {
      if (SessionTokenUtil.pending === request) {
        SessionTokenUtil.pending = null;
        SessionTokenUtil.pendingRevision = -1;
      }
    }
  }

  private static async refresh(snapshot: CredentialSnapshot): Promise<string> {
    const refresh = snapshot.values[REFRESH_TOKEN_KEY];
    if (!refresh) {
      throw new Error('Login required: missing refresh token');
    }
    const response = await refreshToken({
      grant_type: GrantType.REFRESH,
      client_id: Header_Client_Name,
      refresh_token: refresh
    });
    await CredentialStore.applyRefresh(snapshot, response);
    // 提交之后的异步间隙也可能退出或切换账号。
    const current = CredentialStore.sessionSync();
    if (current.owner !== snapshot.owner || current.values[ACCESS_TOKEN_KEY] !== response.access_token) {
      throw new Error('Credential session changed');
    }
    return response.access_token;
  }
}
