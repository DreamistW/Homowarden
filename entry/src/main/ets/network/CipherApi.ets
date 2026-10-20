import { createHttpClient } from './HttpClient';
import {
  Cipher,
  CipherAttachmentRequest,
  CipherFido2Credential,
  CipherFido2CredentialJsonRequest,
  CipherUri,
  CipherUriJsonRequest,
  CipherPasswordHistory,
  CipherPasswordHistoryJsonRequest,
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

const SYNC_TIMEOUT_MS = 60000;

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
  const client = createHttpClient(baseURL, { timeout: SYNC_TIMEOUT_MS });
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

// 所有完整写入共用此边界。加密文本只能是有效密文或 null，不能原样发送空串。
// 按协议字段显式映射，避免误处理 type、match、linkedId、布尔值和日期等元数据。
function buildCipherJsonRequest(cipher: Cipher, includeLastKnownRevisionDate: boolean,
  userId: string): CipherJsonRequest {
  return {
    notes: cipher.notes || null,
    attachments2: buildAttachmentRequests(cipher.attachments2),
    reprompt: cipher.reprompt,
    passwordHistory: cipher.passwordHistory ? cipher.passwordHistory.map(
      (entry: CipherPasswordHistory): CipherPasswordHistoryJsonRequest => ({
        password: entry.password || null,
        lastUsedDate: entry.lastUsedDate
      })) : null,
    lastKnownRevisionDate: includeLastKnownRevisionDate ? (cipher.lastKnownRevisionDate || cipher.revisionDate) : null,
    type: cipher.type,
    login: cipher.login ? {
      username: cipher.login.username || null,
      password: cipher.login.password || null,
      totp: cipher.login.totp || null,
      passwordRevisionDate: cipher.login.passwordRevisionDate,
      uris: (cipher.login.uris || []).map((uri: CipherUri): CipherUriJsonRequest => ({
        uri: uri.uri || null,
        uriChecksum: uri.uriChecksum || null,
        match: uri.match
      })),
      uri: cipher.login.uri || null,
      autofillOnPageLoad: cipher.login.autofillOnPageLoad,
      fido2Credentials: cipher.login.fido2Credentials ? cipher.login.fido2Credentials.map(
        (credential: CipherFido2Credential): CipherFido2CredentialJsonRequest => ({
          credentialId: credential.credentialId || null,
          keyType: credential.keyType || null,
          keyAlgorithm: credential.keyAlgorithm || null,
          keyCurve: credential.keyCurve || null,
          keyValue: credential.keyValue || null,
          rpId: credential.rpId || null,
          rpName: credential.rpName || null,
          userHandle: credential.userHandle || null,
          userName: credential.userName || null,
          userDisplayName: credential.userDisplayName || null,
          counter: credential.counter || null,
          discoverable: credential.discoverable || null,
          creationDate: credential.creationDate
        })) : null
    } : null,
    secureNote: cipher.secureNote,
    sshKey: cipher.sshKey ? {
      publicKey: cipher.sshKey.publicKey || null,
      privateKey: cipher.sshKey.privateKey || null,
      keyFingerprint: cipher.sshKey.keyFingerprint || null
    } : null,
    bankAccount: cipher.bankAccount ? {
      bankName: cipher.bankAccount.bankName || null,
      nameOnAccount: cipher.bankAccount.nameOnAccount || null,
      accountType: cipher.bankAccount.accountType || null,
      accountNumber: cipher.bankAccount.accountNumber || null,
      routingNumber: cipher.bankAccount.routingNumber || null,
      branchNumber: cipher.bankAccount.branchNumber || null,
      pin: cipher.bankAccount.pin || null,
      swiftCode: cipher.bankAccount.swiftCode || null,
      iban: cipher.bankAccount.iban || null,
      bankContactPhone: cipher.bankAccount.bankContactPhone || null
    } : null,
    driversLicense: cipher.driversLicense ? {
      firstName: cipher.driversLicense.firstName || null,
      middleName: cipher.driversLicense.middleName || null,
      lastName: cipher.driversLicense.lastName || null,
      licenseNumber: cipher.driversLicense.licenseNumber || null,
      dateOfBirth: cipher.driversLicense.dateOfBirth || null,
      issuingCountry: cipher.driversLicense.issuingCountry || null,
      issuingAuthority: cipher.driversLicense.issuingAuthority || null,
      issuingState: cipher.driversLicense.issuingState || null,
      issueDate: cipher.driversLicense.issueDate || null,
      expirationDate: cipher.driversLicense.expirationDate || null,
      licenseClass: cipher.driversLicense.licenseClass || null
    } : null,
    passport: cipher.passport ? {
      surname: cipher.passport.surname || null,
      givenName: cipher.passport.givenName || null,
      dateOfBirth: cipher.passport.dateOfBirth || null,
      birthPlace: cipher.passport.birthPlace || null,
      sex: cipher.passport.sex || null,
      nationality: cipher.passport.nationality || null,
      passportNumber: cipher.passport.passportNumber || null,
      passportType: cipher.passport.passportType || null,
      issuingCountry: cipher.passport.issuingCountry || null,
      issuingAuthority: cipher.passport.issuingAuthority || null,
      issueDate: cipher.passport.issueDate || null,
      expirationDate: cipher.passport.expirationDate || null,
      nationalIdentificationNumber: cipher.passport.nationalIdentificationNumber || null
    } : null,
    folderId: cipher.folderId,
    organizationId: cipher.organizationId,
    // 身份信息也属于加密字段；原始空串会令网页版 EncString 解析失败。
    // 在共用请求边界兜底，覆盖新建、编辑、导入和旧数据重新保存。
    identity: cipher.identity ? {
      title: cipher.identity.title || null,
      firstName: cipher.identity.firstName || null,
      middleName: cipher.identity.middleName || null,
      lastName: cipher.identity.lastName || null,
      username: cipher.identity.username || null,
      company: cipher.identity.company || null,
      ssn: cipher.identity.ssn || null,
      passportNumber: cipher.identity.passportNumber || null,
      licenseNumber: cipher.identity.licenseNumber || null,
      email: cipher.identity.email || null,
      phone: cipher.identity.phone || null,
      address1: cipher.identity.address1 || null,
      address2: cipher.identity.address2 || null,
      address3: cipher.identity.address3 || null,
      city: cipher.identity.city || null,
      state: cipher.identity.state || null,
      postalCode: cipher.identity.postalCode || null,
      country: cipher.identity.country || null
    } : null,
    name: cipher.name || null,
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

function buildAttachmentRequests(source: Record<string, CipherAttachmentRequest> | null | undefined):
  Record<string, CipherAttachmentRequest> | null {
  if (!source) {
    return null;
  }
  const attachments: Record<string, CipherAttachmentRequest> = {};
  for (const id of Object.keys(source)) {
    const attachment = source[id];
    attachments[id] = {
      id: attachment.id,
      fileName: attachment.fileName || null,
      key: attachment.key || null
    };
  }
  return attachments;
}
