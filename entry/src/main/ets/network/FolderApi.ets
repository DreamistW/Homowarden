import { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import { createHttpClient } from './HttpClient';
import { getServerEndpoints } from './ServerEndpointResolver';
import { SessionTokenUtil } from '../utils/SessionTokenUtil';
import { VaultFolder } from '../model/FolderModels';

/** 与 Bitwarden 文件夹请求保持一致，仅发送密文名称。 */
interface FolderRequest { name: string; }

/** 文件夹接口只接收账户密钥加密后的名称。 */
export async function saveFolder(id: string, encryptedName: string): Promise<VaultFolder> {
  const client = createHttpClient((await getServerEndpoints()).apiBaseUrl);
  const token = await SessionTokenUtil.getAccessToken();
  const config: AxiosRequestConfig = { headers: { Authorization: `Bearer ${token}` } };
  const request: FolderRequest = { name: encryptedName };
  const response: AxiosResponse<VaultFolder> = id ?
    await client.put(`/folders/${id}`, request, config) :
    await client.post('/folders', request, config);
  return response.data;
}

/** 服务端删除文件夹会解除归属，不删除其中的密码项。 */
export async function deleteFolder(id: string): Promise<void> {
  const client = createHttpClient((await getServerEndpoints()).apiBaseUrl);
  const token = await SessionTokenUtil.getAccessToken();
  await client.delete(`/folders/${id}`, { headers: { Authorization: `Bearer ${token}` } });
}
