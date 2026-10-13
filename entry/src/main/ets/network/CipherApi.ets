import { createHttpClient } from './HttpClient';
import {
  Cipher,
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
  const request = buildCipherJsonRequest(cipher, false);
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
  const request = buildCipherJsonRequest(cipher, true);
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

function buildCipherJsonRequest(cipher: Cipher, includeLastKnownRevisionDate: boolean): CipherJsonRequest {
  return {
    notes: cipher.notes,
    attachments2: cipher.attachments2 || null,
    reprompt: cipher.reprompt,
    passwordHistory: cipher.passwordHistory || null,
    lastKnownRevisionDate: includeLastKnownRevisionDate ? (cipher.lastKnownRevisionDate || cipher.revisionDate) : null,
    type: cipher.type,
    login: cipher.login,
    secureNote: cipher.secureNote,
    sshKey: cipher.sshKey || null,
    bankAccount: cipher.bankAccount || null,
    driversLicense: cipher.driversLicense || null,
    passport: cipher.passport || null,
    folderId: cipher.folderId,
    organizationId: cipher.organizationId,
    identity: cipher.identity,
    name: cipher.name,
    fields: cipher.fields || null,
    favorite: cipher.favorite,
    card: cipher.card,
    key: cipher.key || null,
    archivedDate: cipher.archivedDate || null,
    encryptedFor: cipher.encryptedFor || null
  };
}
