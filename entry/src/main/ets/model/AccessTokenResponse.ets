export interface AccessTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
  refresh_token: string;
  // 可根据实际API返回补充其他字段
} 