import { AxiosResponse } from '@ohos/axios';
import { bundleManager } from '@kit.AbilityKit';
import { Logger } from '@nzy/logger';
import { ResolvedServerEndpoints, ServerConfigResponse } from '../model/ServerEnvironment';
import { ServerType } from '../utils/Constants';
import { createHttpClient, getServerConfig } from './HttpClient';

const VERSION_TIMEOUT_MS = 3000;

/** 登录诊断独立于认证结果；只输出类型和版本，不能记录配置对象、地址或网络异常。 */
export async function logLoginEnvironment(endpoints: ResolvedServerEndpoints): Promise<void> {
  let serverType = 'UNKNOWN';
  let clientVersionCode = 'unknown';
  let serverVersion = 'unknown';
  try {
    serverType = serverTypeLabel((await getServerConfig()).serverType);
  } catch (_) {
    // 配置读取失败仍保留其余诊断信息。
  }
  try {
    const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    clientVersionCode = info.versionCode.toString();
  } catch (_) {
    // 不能用 versionName 或协议兼容版本代替 versionCode。
  }
  try {
    serverVersion = await fetchServerVersion(endpoints.apiBaseUrl);
  } catch (_) {
    // 诊断失败不影响登录，也不把可能包含地址的异常写入日志。
  }
  Logger.info(`[Login] Environment: serverType=${serverType}, serverVersion=${serverVersion}, ` +
    `clientVersionCode=${clientVersionCode}`);
}

function serverTypeLabel(type: ServerType): string {
  switch (type) {
    case ServerType.US: return 'US';
    case ServerType.EU: return 'EU';
    case ServerType.SELF_HOSTED: return 'SELF_HOSTED';
    default: return 'UNKNOWN';
  }
}

/** 只接收版本格式，防止服务端把地址、HTML 或其他内容塞进版本字段进入日志。 */
function versionText(value: string | null | undefined): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const version = value.trim();
  return version.length <= 64 && /^[vV]?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)*$/.test(version) ? version : null;
}

async function fetchServerVersion(apiBaseUrl: string): Promise<string> {
  const client = createHttpClient(apiBaseUrl, { timeout: VERSION_TIMEOUT_MS });
  try {
    const response: AxiosResponse<string> = await client.get('/version');
    const version = versionText(response.data);
    if (version) {
      return version;
    }
  } catch (_) {
    // 某些 Bitwarden 服务只提供 /config。
  }
  try {
    const response: AxiosResponse<ServerConfigResponse> = await client.get('/config');
    // Vaultwarden 的 /config.version 是 Bitwarden 兼容版本，不是 Vaultwarden 自身版本。
    if (response.data.server?.name?.toLowerCase() === 'vaultwarden') {
      return 'unknown';
    }
    return versionText(response.data.version) ?? 'unknown';
  } catch (_) {
    return 'unknown';
  }
}
