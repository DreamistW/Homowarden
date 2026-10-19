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
  server?: ServerSoftware | null;
  environment?: ServerEnvironmentUrls | null;
}

export interface ServerSoftware {
  name?: string | null;
}

export interface ResolvedServerEndpoints {
  vaultBaseUrl: string;
  apiBaseUrl: string;
  identityBaseUrl: string;
}
