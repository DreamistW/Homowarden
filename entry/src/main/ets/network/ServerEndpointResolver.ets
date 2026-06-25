import { AxiosResponse } from '@ohos/axios';
import { Logger } from '@nzy/logger';
import { ResolvedServerEndpoints, ServerConfigResponse } from '../model/ServerEnvironment';
import { ServerConfig } from '../model/ServerConfig';
import { SERVER_BASE_URL_EU, SERVER_BASE_URL_US, ServerType } from '../utils/Constants';
import { createHttpClient, getServerConfig } from './HttpClient';

interface ParsedHttpUrl {
  scheme: string;
  host: string;
  hostName: string;
  origin: string;
  path: string;
}

let cachedServerKey = '';
let cachedEndpoints: ResolvedServerEndpoints | null = null;

export async function getServerEndpoints(forceRefresh: boolean = false): Promise<ResolvedServerEndpoints> {
  const serverConfig = await getServerConfig();
  const cacheKey = `${serverConfig.serverType}:${serverConfig.serverAddress}`;
  if (!forceRefresh && cachedEndpoints !== null && cachedServerKey === cacheKey) {
    return cachedEndpoints;
  }

  let endpoints = buildDefaultEndpoints(serverConfig);
  if (serverConfig.serverType === ServerType.SELF_HOSTED) {
    endpoints = await resolveSelfHostedEndpoints(endpoints);
  }

  cachedServerKey = cacheKey;
  cachedEndpoints = endpoints;
  return endpoints;
}

function buildDefaultEndpoints(serverConfig: ServerConfig): ResolvedServerEndpoints {
  if (serverConfig.serverType === ServerType.US) {
    return {
      vaultBaseUrl: `https://vault.${SERVER_BASE_URL_US}`,
      apiBaseUrl: `https://api.${SERVER_BASE_URL_US}`,
      identityBaseUrl: `https://identity.${SERVER_BASE_URL_US}`
    };
  }

  if (serverConfig.serverType === ServerType.EU) {
    return {
      vaultBaseUrl: `https://vault.${SERVER_BASE_URL_EU}`,
      apiBaseUrl: `https://api.${SERVER_BASE_URL_EU}`,
      identityBaseUrl: `https://identity.${SERVER_BASE_URL_EU}`
    };
  }

  const vaultBaseUrl = normalizeSelfHostedBaseUrl(serverConfig.serverAddress);
  return {
    vaultBaseUrl,
    apiBaseUrl: appendPath(vaultBaseUrl, 'api'),
    identityBaseUrl: appendPath(vaultBaseUrl, 'identity')
  };
}

async function resolveSelfHostedEndpoints(fallback: ResolvedServerEndpoints): Promise<ResolvedServerEndpoints> {
  try {
    const client = createHttpClient(fallback.apiBaseUrl);
    const response: AxiosResponse<ServerConfigResponse> = await client.get('/config');
    const environment = response.data.environment;
    if (!environment) {
      return fallback;
    }

    return {
      vaultBaseUrl: normalizeEnvironmentUrl(environment.vault, fallback.vaultBaseUrl, '', fallback.vaultBaseUrl),
      apiBaseUrl: normalizeEnvironmentUrl(environment.api, fallback.vaultBaseUrl, 'api', fallback.apiBaseUrl),
      identityBaseUrl: normalizeEnvironmentUrl(
        environment.identity,
        fallback.vaultBaseUrl,
        'identity',
        fallback.identityBaseUrl
      )
    };
  } catch (err) {
    const error = err as Error;
    Logger.info(`Failed to fetch server config, use fallback endpoints. Error: ${error.message}`);
    return fallback;
  }
}

function normalizeSelfHostedBaseUrl(serverAddress: string | null | undefined): string {
  const value = serverAddress?.trim() ?? '';
  if (value.length === 0) {
    throw new Error('Self-hosted server address is empty');
  }

  if (/^https?:\/\//i.test(value)) {
    return trimTrailingSlash(value);
  }

  return trimTrailingSlash(`https://${value}`);
}

function normalizeEnvironmentUrl(
  configuredUrl: string | null | undefined,
  externalBaseUrl: string,
  defaultPath: string,
  fallbackUrl: string
): string {
  const rawUrl = configuredUrl?.trim() ?? '';
  if (rawUrl.length === 0) {
    return fallbackUrl;
  }

  if (rawUrl.startsWith('/')) {
    return buildExternalUrlWithPath(externalBaseUrl, rawUrl);
  }

  const parsedUrl = parseHttpUrl(rawUrl);
  const externalUrl = parseHttpUrl(externalBaseUrl);
  if (!parsedUrl || !externalUrl) {
    return fallbackUrl;
  }

  if (shouldRewriteWithExternalOrigin(parsedUrl, externalUrl)) {
    const path = parsedUrl.path.length > 0 ? parsedUrl.path : defaultPath;
    return path.length > 0 ? buildExternalUrlWithPath(externalBaseUrl, path) : externalBaseUrl;
  }

  return trimTrailingSlash(`${parsedUrl.origin}${parsedUrl.path}`);
}

function shouldRewriteWithExternalOrigin(configUrl: ParsedHttpUrl, externalUrl: ParsedHttpUrl): boolean {
  if (configUrl.scheme === externalUrl.scheme && configUrl.host === externalUrl.host) {
    return false;
  }

  if (configUrl.hostName === externalUrl.hostName) {
    return true;
  }

  return isUnreachableFromDevice(configUrl.hostName);
}

function isUnreachableFromDevice(hostName: string): boolean {
  const host = hostName.toLowerCase();
  if (host === 'localhost' || host === '0.0.0.0' || host === '[::1]' || host === '::1') {
    return true;
  }

  if (host.startsWith('127.')) {
    return true;
  }

  if (isPrivateIpv4(host)) {
    return true;
  }

  return !host.includes('.') && !isIpv4(host);
}

function isPrivateIpv4(hostName: string): boolean {
  const parts = hostName.split('.');
  if (parts.length !== 4) {
    return false;
  }

  const numbers = parts.map((part: string) => Number(part));
  if (numbers.some((part: number) => Number.isNaN(part) || part < 0 || part > 255)) {
    return false;
  }

  return numbers[0] === 10 ||
    numbers[0] === 127 ||
    (numbers[0] === 172 && numbers[1] >= 16 && numbers[1] <= 31) ||
    (numbers[0] === 192 && numbers[1] === 168) ||
    (numbers[0] === 169 && numbers[1] === 254);
}

function isIpv4(hostName: string): boolean {
  const parts = hostName.split('.');
  if (parts.length !== 4) {
    return false;
  }

  return parts.every((part: string) => {
    const value = Number(part);
    return !Number.isNaN(value) && value >= 0 && value <= 255;
  });
}

function parseHttpUrl(url: string): ParsedHttpUrl | null {
  const match = url.trim().match(/^(https?):\/\/([^\/?#]+)(\/[^?#]*)?/i);
  if (!match) {
    return null;
  }

  const scheme = match[1].toLowerCase();
  const host = match[2];
  const hostName = extractHostName(host);
  const path = normalizePath(match[3] ?? '');
  return {
    scheme,
    host,
    hostName,
    origin: `${scheme}://${host}`,
    path
  };
}

function extractHostName(host: string): string {
  if (host.startsWith('[')) {
    const endIndex = host.indexOf(']');
    return endIndex >= 0 ? host.substring(0, endIndex + 1).toLowerCase() : host.toLowerCase();
  }

  const colonIndex = host.indexOf(':');
  return (colonIndex >= 0 ? host.substring(0, colonIndex) : host).toLowerCase();
}

function buildExternalUrlWithPath(externalBaseUrl: string, path: string): string {
  const normalizedPath = normalizePath(path);
  if (normalizedPath.length === 0) {
    return externalBaseUrl;
  }

  const externalUrl = parseHttpUrl(externalBaseUrl);
  if (!externalUrl) {
    return appendPath(externalBaseUrl, normalizedPath);
  }

  if (externalUrl.path.length > 0 &&
    (normalizedPath === externalUrl.path || normalizedPath.startsWith(`${externalUrl.path}/`))) {
    return trimTrailingSlash(`${externalUrl.origin}${normalizedPath}`);
  }

  return appendPath(externalBaseUrl, normalizedPath);
}

function appendPath(baseUrl: string, path: string): string {
  const normalizedPath = path.replace(/^\/+/, '');
  if (normalizedPath.length === 0) {
    return trimTrailingSlash(baseUrl);
  }
  return `${trimTrailingSlash(baseUrl)}/${normalizedPath}`;
}

function normalizePath(path: string): string {
  const value = path.trim();
  if (value.length === 0 || value === '/') {
    return '';
  }
  return `/${value.replace(/^\/+/, '').replace(/\/+$/, '')}`;
}

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, '');
}
