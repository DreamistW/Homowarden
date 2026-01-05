export interface SendEmailLoginRequest {
  authRequestAccessCode: string,
  authRequestId: string,
  deviceIdentifier: string,
  email: string,
  masterPasswordHash: string,
  ssoEmail2FaSessionToken: string
}