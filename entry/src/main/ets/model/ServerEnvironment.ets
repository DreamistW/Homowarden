export interface ServerEnvironmentUrls {
  vault?: string | null;
  api?: string | null;
  identity?: string | null;
  notifications?: string | null;
  sso?: string | null;
}

export interface ServerConfigResponse {
  object?: string | null;
  version?: string | null;
  gitHash?: string | null;
  environment?: ServerEnvironmentUrls | null;
}

export interface ResolvedServerEndpoints {
  vaultBaseUrl: string;
  apiBaseUrl: string;
  identityBaseUrl: string;
}
