export interface RefreshTokenResponse{
  access_token: string;
  expires_in: number;
  refresh_token: string;
  scope: string;
  token_type: string;
}

export interface RefreshTokenRequest{
  refresh_token: string;
  grant_type: string;
  client_id: string;
}