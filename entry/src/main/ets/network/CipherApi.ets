import { createHttpClient, getServerConfig } from './HttpClient';
import { Cipher } from '../model/CipherModels';
import { Logger } from '@nzy/logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { deleteAsset, queryAssetSync, updateAsset } from '../utils/AssetUtil';
import {
  ACCESS_TOKEN_KEY_1,
  ACCESS_TOKEN_KEY_2,
  GrantType,
  Header_Client_Name,
  REFRESH_TOKEN_KEY,
  SERVER_BASE_URL_EU,
  SERVER_BASE_URL_US,
  ServerType,
  TOKEN_EXPIRE_TIME_KEY
} from '../utils/Constants';
import { refreshToken } from './AuthApi';
import { AxiosResponse } from '@ohos/axios';
import { RefreshTokenRequest } from '../model/RefreshToken';
import { asset } from '@kit.AssetStoreKit';

/**
 * 密码库列表响应结构
 */
export interface CipherListResponse {
  continuationToken: string | null; // 分页用token，通常为null
  data: Cipher[]; // 密码项数组
  object: string; // 类型标识，通常为"list"
}

/**
 * 获取access_token，支持分段拼接和过期自动刷新
 */
async function getAccessToken(): Promise<string> {
  // 获取token过期时间戳
  const expireTimestampStr = queryAssetSync(TOKEN_EXPIRE_TIME_KEY);
  const expireTimestamp = expireTimestampStr ? parseInt(expireTimestampStr) : 0;
  const now = Math.floor(Date.now() / 1000);
  let token = '';

  // 判断是否过期
  if (expireTimestamp > 0 && now >= expireTimestamp - 120) {
    // 已过期，刷新token
    try {
      const refreshRequest: RefreshTokenRequest = {
        refresh_token: queryAssetSync(REFRESH_TOKEN_KEY),
        client_id: Header_Client_Name,
        grant_type: GrantType.REFRESH
      }
      const newTokenObj = await refreshToken(refreshRequest);
      Logger.info("Refresh token successfully");
      if (newTokenObj && newTokenObj.access_token) {
        // 分段保存新token
        if (newTokenObj.access_token.length > 1000) {
          updateAsset(ACCESS_TOKEN_KEY_1, asset.Tag.SECRET, newTokenObj.access_token.substring(0, 1000));
          updateAsset(ACCESS_TOKEN_KEY_2, asset.Tag.SECRET, newTokenObj.access_token.substring(1000));
        } else {
          updateAsset(ACCESS_TOKEN_KEY_1, asset.Tag.SECRET, newTokenObj.access_token);
          deleteAsset(ACCESS_TOKEN_KEY_2);
        }
        let expireTime = Math.floor(Date.now() / 1000) + newTokenObj.expires_in;
        updateAsset(TOKEN_EXPIRE_TIME_KEY, asset.Tag.SECRET, String(expireTime));
        token = newTokenObj.access_token;
      }
    } catch (err) {
      let error = err as BusinessError;
      Logger.error(`Failed to refresh token, error message: ${error.message}`);
    }
  } else {
    let token1 = queryAssetSync(ACCESS_TOKEN_KEY_1);
    let token2 = queryAssetSync(ACCESS_TOKEN_KEY_2);
    token = token2 && token2.length > 0 ? token1 + token2 : token1;
  }
  return token;
}

/**
 * 获取基础URL
 */
async function getApiBaseUrl(): Promise<string> {
  const serverConfig = await getServerConfig();
  if (serverConfig.serverType == ServerType.US) {
    return `https://api.${SERVER_BASE_URL_US}`;
  } else if (serverConfig.serverType == ServerType.EU) {
    return `https://api.${SERVER_BASE_URL_EU}`;
  } else {
    return `https://${serverConfig.serverAddress}/api`;
  }
}

/**
 * 获取所有密码项
 * @returns CipherListResponse 结构
 */
export async function getAllCiphers(): Promise<CipherListResponse> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await getAccessToken();
  return client.get('/ciphers', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }).then((response: AxiosResponse<CipherListResponse>) => {
    return response.data;
  }).catch((error: BusinessError) => {
    Logger.error('Failed to fetch ciphers: ' + error.message);
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
  const token = await getAccessToken();
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
  const token = await getAccessToken();
  return client.post('/ciphers', cipher, {
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
  const token = await getAccessToken();
  return client.put(`/ciphers/${id}`, cipher, {
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
 * 将密码项移至回收站
 * @param id 密码项ID
 */
export async function moveCipherToRecycler(id: string): Promise<void> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await getAccessToken();
  return client.put(`/ciphers/${id}/delete`, id, {
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
 * @returns
 */
export async function deleteCipher(id: string): Promise<void> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await getAccessToken();
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
 * @param cipher 密码项对象
 * @returns
 */
export async function restoreCipher(id: string, cipher: Cipher): Promise<Cipher> {
  const baseURL = await getApiBaseUrl();
  const client = createHttpClient(baseURL);
  const token = await getAccessToken();
  return client.put(`/ciphers/${id}/restore`, cipher, {
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