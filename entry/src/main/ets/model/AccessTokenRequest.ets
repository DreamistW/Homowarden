export interface AccessTokenRequest {
  grant_type: string;
  username: string;
  password: string;
  scope: string;
  client_id: string;
} 