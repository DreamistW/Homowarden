/** 刷新授权成功后的标准令牌响应。 */
export interface RefreshTokenResponse{
  access_token: string;
  /** 新访问令牌有效秒数。 */
  expires_in: number;
  refresh_token: string;
  scope: string;
  token_type: string;
}

/** 刷新令牌表单请求。 */
export interface RefreshTokenRequest{
  refresh_token: string;
  grant_type: string;
  client_id: string;
}
