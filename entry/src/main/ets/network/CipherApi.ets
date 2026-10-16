import { createHttpClient } from './HttpClient';
import {
  Cipher,
  CipherField,
  CipherFieldJsonRequest,
  CipherJsonRequest,
  CipherPartialRequest,
  CreateCipherInOrganizationRequest,
  VaultSyncResponse
} from '../model/CipherModels';
import { Logger } from '@nzy/logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { SessionTokenUtil } from '../utils/SessionTokenUtil';
import { AxiosResponse } from '@ohos/axios';
import { getServerEndpoints } from './ServerEndpointResolver';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { util } from '@kit.ArkTS';

/**
 * 获取基础URL
 */
async function getApiBaseUrl(): Promise<string> {
  return (await getServerEndpoints()).apiBaseUrl;
}

/**
 * 同步密码库数据
 * @returns 官方 /sync 响应结构
 */
export async function getAllCiphers(): Promise<VaultSyncResponse> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  return client.get('/sync', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then((response: AxiosResponse<VaultSyncResponse>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to sync vault: ' + ErrorMessageUtil.getMessage(error as Object));
    return Promise.reject(error);
  });
}

/**
 * 获取单个密码项
 * @param id 密码项ID
 * @returns Cipher 对象
 */
export async function getCipherById(id: string): Promise<Cipher> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  return client.get(`/ciphers/${id}`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then((response: AxiosResponse<Cipher>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to fetch cipher item: ' + error.message);
    return Promise.reject(error);
  });
}

/**
 * 新增密码项
 * @param cipher 密码项对象
 * @returns 新增后的Cipher对象
 */
export async function createCipher(cipher: Cipher): Promise<Cipher> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  const request = buildCipherJsonRequest(cipher, false, getCipherUserId(token));
  const endpoint = cipher.organizationId ? '/ciphers/create' : '/ciphers';
  const body: CipherJsonRequest | CreateCipherInOrganizationRequest = cipher.organizationId ? {
    Cipher: request,
    CollectionIds: cipher.collectionIds || []
  } : request;
  return client.post(endpoint, body, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then((response: AxiosResponse<Cipher>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to create cipher item: ' + error.message);
    return Promise.reject(error);
  });
}

/** 导入已在本地加密的个人条目；文件中的归属、ID 和密钥不参与请求。 */
export async function importCiphers(ciphers: Cipher[], shouldContinue: () => boolean): Promise<void> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  if (!shouldContinue()) {
    throw new Error('transfer_session_expired');
  }
  const userId = getCipherUserId(token);
  const body: CipherImportRequest = {
    ciphers: ciphers.map((cipher: Cipher): CipherJsonRequest => {
      return buildCipherJsonRequest(cipher, false, userId);
    }),
    folders: [],
    folderRelationships: []
  };
  await client.post('/ciphers/import', body, { headers: { 'Authorization': `Bearer ${token}` } });
}

interface CipherTokenClaims {
  sub?: string;
}

function getCipherUserId(token: string): string {
  const payload = token.split('.')[1];
  if (!payload) {
    throw new Error('transfer_session_expired');
  }
  const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - base64.length % 4) % 4);
  const claims: CipherTokenClaims = JSON.parse(new util.TextDecoder().decodeToString(
    new util.Base64Helper().decodeSync(padded)));
  if (!claims || typeof claims.sub !== 'string' || !claims.sub) {
    throw new Error('transfer_session_expired');
  }
  return claims.sub;
}

interface CipherImportRequest {
  ciphers: CipherJsonRequest[];
  folders: Object[];
  folderRelationships: Object[];
}

/**
 * 更新密码项
 * @param id 密码项ID
 * @param cipher 密码项对象
 * @returns 更新后的Cipher对象
 */
export async function updateCipher(id: string, cipher: Cipher): Promise<Cipher> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  const request = buildCipherJsonRequest(cipher, true, getCipherUserId(token));
  return client.put(`/ciphers/${id}`, request, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then((response: AxiosResponse<Cipher>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to update cipher item: ' + error.message);
    return Promise.reject(error);
  });
}

/**
 * 更新密码项无需重新加密的属性
 */
export async function updateCipherPartial(id: string, request: CipherPartialRequest): Promise<Cipher> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  return client.put(`/ciphers/${id}/partial`, request, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then((response: AxiosResponse<Cipher>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to update cipher item partially: ' + error.message);
    return Promise.reject(error);
  });
}

/**
 * 将密码项移至回收站
 * @param id 密码项ID
 */
export async function moveCipherToRecycler(id: string): Promise<void> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  return client.put(`/ciphers/${id}/delete`, undefined, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then(() => {
    return;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to recycle cipher item: ' + error.message);
    return Promise.reject(error);
  });
}

/**
 * 彻底删除密码项
 * @param id 密码项ID
 */
export async function deleteCipher(id: string): Promise<void> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  return client.delete(`/ciphers/${id}`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then(() => {
    return;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to delete cipher item: ' + error.message);
    return Promise.reject(error);
  });
}

/**
 * 还原密码项
 * @param id 密码项ID
 * @returns 还原后的密码项
 */
export async function restoreCipher(id: string): Promise<Cipher> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await SessionTokenUtil.getAccessToken();
  return client.put(`/ciphers/${id}/restore`, undefined, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then((response: AxiosResponse<Cipher>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to update cipher item: ' + error.message);
    return Promise.reject(error);
  });
}

function buildCipherJsonRequest(cipher: Cipher, includeLastKnownRevisionDate: boolean,
  userId: string): CipherJsonRequest {
  return {
    notes: cipher.notes || null,
    attachments2: cipher.attachments2 || null,
    reprompt: cipher.reprompt,
    passwordHistory: cipher.passwordHistory || null,
    lastKnownRevisionDate: includeLastKnownRevisionDate ? (cipher.lastKnownRevisionDate || cipher.revisionDate) : null,
    type: cipher.type,
    login: cipher.login ? {
      username: cipher.login.username || null,
      password: cipher.login.password || null,
      totp: cipher.login.totp || null,
      passwordRevisionDate: cipher.login.passwordRevisionDate,
      uris: cipher.login.uris,
      uri: cipher.login.uri || null,
      autofillOnPageLoad: cipher.login.autofillOnPageLoad,
      fido2Credentials: cipher.login.fido2Credentials
    } : null,
    secureNote: cipher.secureNote,
    sshKey: cipher.sshKey || null,
    bankAccount: cipher.bankAccount || null,
    driversLicense: cipher.driversLicense || null,
    passport: cipher.passport || null,
    folderId: cipher.folderId,
    organizationId: cipher.organizationId,
    identity: cipher.identity,
    name: cipher.name,
    fields: cipher.fields ? cipher.fields.map((field: CipherField): CipherFieldJsonRequest => ({
      name: field.name || null,
      value: field.value || null,
      type: field.type,
      linkedId: field.linkedId
    })) : null,
    favorite: cipher.favorite,
    // 新增、编辑和批量导入均经过此处；兼容旧数据和表单中的空字符串。
    card: cipher.card ? {
      cardholderName: cipher.card.cardholderName || null,
      brand: cipher.card.brand || null,
      number: cipher.card.number || null,
      expMonth: cipher.card.expMonth || null,
      expYear: cipher.card.expYear || null,
      code: cipher.card.code || null
    } : null,
    key: cipher.key || null,
    archivedDate: cipher.archivedDate || null,
    // 新建、编辑和导入均声明当前令牌用户，不能沿用响应或文件中缺失、过期的归属。
    encryptedFor: userId
  };
}
