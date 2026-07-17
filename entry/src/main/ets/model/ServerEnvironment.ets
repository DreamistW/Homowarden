/** 自托管服务器 `/config` 响应中的可选服务地址。 */
export interface ServerEnvironmentUrls {
  vault?: string | null;
  api?: string | null;
  identity?: string | null;
  notifications?: string | null;
  sso?: string | null;
}

/** 自托管服务器公开配置响应；旧版本服务端可能省略任意字段。 */
export interface ServerConfigResponse {
  object?: string | null;
  version?: string | null;
  gitHash?: string | null;
  environment?: ServerEnvironmentUrls | null;
}

/** 经预设、服务端配置和设备可达性规则归一化后的请求基址。 */
export interface ResolvedServerEndpoints {
  /** 用户可访问的网页端 origin，用于认证请求的 Origin 头。 */
  vaultBaseUrl: string;
  /** 密码库及账号业务 API 基址。 */
  apiBaseUrl: string;
  /** 预登录、登录和刷新令牌使用的身份服务基址。 */
  identityBaseUrl: string;
}
