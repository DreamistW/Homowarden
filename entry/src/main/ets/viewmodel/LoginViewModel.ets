import { accessToken, prelogin, resendNewDeviceOtp, sendEmailLogin } from '../network/AuthApi';
import {
  DeviceType,
  EMAIL_KEY,
  ACCESS_TOKEN_KEY,
  PRIVATE_KEY,
  GrantType,
  Header_Client_Name,
  KDF_PARAM_KEY,
  MASTER_KEY,
  REFRESH_TOKEN_KEY,
  SCOPE_KEY,
  SERVER_ADDRESS_KEY,
  SERVER_TYPE_KEY,
  ServerType,
  TOKEN_EXPIRE_TIME_KEY,
  TWO_FACTOR_TOKEN_KEY,
  USER_KEY
} from '../utils/Constants';
import { Logger } from '@nzy/logger';
import { CryptoUtil } from '../utils/CryptoUtil';
import { DeviceUtil } from '../utils/DeviceUtil';
import { DataPreferences } from '@abner/datastore';
import { util } from '@kit.ArkTS';
import { CredentialStore } from '../utils/CredentialStore';
import { getServerConfig } from '../network/HttpClient';
import { AccessTokenRequest, AccessTokenResponse, TwoFactorProvider, TwoFactorProviderData } from '../model/AccessToken';
import { KdfParameters, PreloginRequest, PreloginResponse } from '../model/Prelogin';
import { KdfUtil } from '../utils/KdfUtil';
import { ResendNewDeviceOtpRequest, SendEmailLoginRequest } from '../model/SendEmailLogin';
import { PasskeyTwoFactorUtil } from '../utils/PasskeyTwoFactorUtil';
import { common } from '@kit.AbilityKit';
import { getServerEndpoints } from '../network/ServerEndpointResolver';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { AppText, AppTextKey } from '../localization/AppText';
import { LoginErrorResponseData, LoginRequestError } from '../model/LoginError';
import { LoginErrorUtil } from '../utils/LoginErrorUtil';
import { DECRYPTION_UNSUPPORTED, LoginDecryptionMaterial, LoginResponseUtil,
  PASSWORD_RESET_REQUIRED } from '../utils/LoginResponseUtil';

/**
 * 编排预登录、密钥派生、多因素验证及凭据持久化的登录状态
 */
export class LoginViewModel {
  // 登录状态
  email: string = '';
  needSaveEmail: boolean = false;
  password: string = '';
  serverAddress: string = '';
  serverType: ServerType = ServerType.US;
  errorMessage: AppText | undefined = undefined;
  successMessage: AppText | undefined = undefined;
  needTwoFactor: boolean = false;
  needNewDevice: boolean = false;
  twoFactorToken: string = '';
  twoFactorRemember: boolean = false;
  twoFactorProvider: number = TwoFactorProvider.AUTHENTICATOR_APP;
  availableTwoFactorProviders: number[] = [];
  twoFactorProviderData: TwoFactorProviderData | null = null;
  twoFactorProvidersData: Record<string, TwoFactorProviderData | null> | null = null;
  ssoEmail2FaSessionToken: string = '';
  // 预登录信息
  kdfType: number = 0; // 0 表示 PBKDF2，1 表示 Argon2id
  kdfIterations: number = 0;
  kdfMemory: number = 0;
  kdfParallelism: number = 0;
  kdfSalt: string = '';
  // 登录结果
  accessTokenResponse: AccessTokenResponse = {} as AccessTokenResponse;
  // 加密相关
  masterKey: string = '';
  loginPassword: string = '';
  // 设备信息
  deviceType: number = DeviceType.ANDROID;
  deviceIdentifier: string = '';
  deviceName: string = '';
  // 设备信息初始化状态
  private deviceInfoInitialized: boolean = false;
  private passkeyChallengeNeedsRefresh: boolean = false;

  constructor() {
    // 初始化同步的设备信息
    this.initializeSyncDeviceInfo();
  }

  // 初始化同步设备信息
  private initializeSyncDeviceInfo(): void {
    this.deviceType = DeviceUtil.getDeviceType();
    this.deviceName = DeviceUtil.getDeviceName();
  }

  // 初始化异步设备信息（设备标识符）
  private async initializeAsyncDeviceInfo(): Promise<void> {
    if (!this.deviceInfoInitialized) {
      try {
        const deviceInfo = await DeviceUtil.getDeviceInfo();
        this.deviceIdentifier = deviceInfo.deviceIdentifier;
        this.deviceInfoInitialized = true;
        Logger.info(`Device info initialized: type=${this.deviceType}`);
      } catch (error) {
        Logger.error(`Failed to initialize device info: ${error}`);
        // 未可靠持久化设备身份时停止登录，不能退回临时 UUID。
        throw new Error('Device identifier persistence failed');
      }
    }
  }

  // 验证输入
  validateInput(): boolean {
    if (!this.email || !this.email.trim()) {
      this.errorMessage = new AppText(AppTextKey.EMAIL_REQUIRED);
      return false;
    }

    if (!this.password || !this.password.trim()) {
      this.errorMessage = new AppText(AppTextKey.PASSWORD_REQUIRED);
      return false;
    }

    if (this.serverType === ServerType.SELF_HOSTED && !this.getNormalizedServerAddress()) {
      this.errorMessage = new AppText(AppTextKey.SERVER_REQUIRED);
      return false;
    }

    return true;
  }

  // 预登录
  async performPrelogin(): Promise<boolean> {
    try {
      const request: PreloginRequest = {
        email: this.email.trim().toLowerCase()
      };
      const response: PreloginResponse = await prelogin(request);

      const params = KdfUtil.normalize(response, request.email);
      this.kdfType = params.kdf;
      this.kdfIterations = params.kdfIterations;
      this.kdfMemory = params.kdfMemory;
      this.kdfParallelism = params.kdfParallelism;
      this.kdfSalt = params.salt as string;

      Logger.info(`Prelogin successful: KDF type=${this.kdfType}, iterations=${this.kdfIterations}, memory=${this.kdfMemory}, parallelism=${this.kdfParallelism}`);
      Logger.info(`Prelogin protocol: parameters=${response.kdfSettings ? 'kdfSettings' : 'legacy'}, ` +
        `saltSource=${response.salt === undefined || response.salt === null ? 'email' : 'server'}`);
      return true;
    } catch (error) {
      Logger.error(`Prelogin failed: ${error}`);
      this.errorMessage = new AppText((error as Error).message?.includes('KDF') ||
        (error as Error).message?.includes('Argon2') ? AppTextKey.KDF_UNSUPPORTED :
        LoginErrorUtil.classify(error as LoginRequestError));
      return false;
    }
  }

  /**
   * 使用服务端下发的 KDF 参数派生主密钥，登录成功后保存到加密数据库供解锁使用
   */
  async deriveMasterKey(): Promise<boolean> {
    try {
      this.masterKey = await CryptoUtil.deriveMasterKey(this.password, this.getAuthenticationKdf());

      Logger.info('Master key derived successfully');
      return true;
    } catch (error) {
      Logger.error(`Master key derivation failed: ${error}`);
      this.errorMessage = new AppText((error as Error).message === 'argon2_resources_unavailable' ?
        AppTextKey.KDF_RESOURCES_UNAVAILABLE : AppTextKey.MASTER_KEY_FAILED);
      return false;
    }
  }

  private getAuthenticationKdf(): KdfParameters {
    return {
      kdf: this.kdfType,
      kdfIterations: this.kdfIterations,
      kdfMemory: this.kdfMemory,
      kdfParallelism: this.kdfParallelism,
      salt: this.kdfSalt
    };
  }

  // 二次派生得到服务器验证值，原始主密码不会作为登录请求的 password 发送
  async hashMasterKey(): Promise<boolean> {
    try {
      // 将Base64主密钥解码为Uint8Array
      const masterKeyBytes = new util.Base64Helper().decodeSync(this.masterKey);
      this.loginPassword = await CryptoUtil.deriveKeyPBKDF2SingleIteration(masterKeyBytes, this.password);
      Logger.info('Hash master key successfully');
      return true;
    } catch (error) {
      Logger.error(`Master key hash failed: ${error}`);
      this.errorMessage = new AppText(AppTextKey.MASTER_KEY_FAILED);
      return false;
    }
  }

  // 执行登录
  async performLogin(): Promise<boolean> {
    try {
      // 确保设备信息已初始化
      await this.initializeAsyncDeviceInfo();

      const request: AccessTokenRequest = {
        grant_type: GrantType.PASSWORD,
        username: this.email.trim().toLowerCase(),
        password: this.loginPassword,
        scope: SCOPE_KEY,
        client_id: Header_Client_Name,
        deviceType: this.deviceType,
        deviceIdentifier: this.deviceIdentifier,
        deviceName: this.deviceName
      };
      this.applyRememberedTwoFactor(request);

      this.accessTokenResponse = await accessToken(request);
      this.successMessage = new AppText(AppTextKey.LOGIN_SUCCESS);
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      const loginError = error as LoginRequestError;
      const errorData = loginError.response?.data;
      if (this.isTwoFactorRequired(errorData)) {
        this.handleTwoFactorRequired(errorData);
        return false;
      }

      if (this.isNewDeviceVerificationRequired(errorData)) {
        this.needNewDevice = true;
        return false;
      }
      const errorMessage = this.extractLoginErrorMessage(loginError);
      Logger.error(`Login failed: ${errorMessage}`);
      this.handleContinuationFailure(loginError);
      return false;
    }
  }

  // 带2FA的登录请求
  async performLoginWith2FA(): Promise<boolean> {
    try {
      const request: AccessTokenRequest = {
        grant_type: GrantType.PASSWORD,
        username: this.email.trim().toLowerCase(),
        password: this.loginPassword,
        scope: SCOPE_KEY,
        client_id: Header_Client_Name,
        deviceType: this.deviceType,
        deviceIdentifier: this.deviceIdentifier,
        deviceName: this.deviceName,
        twoFactorToken: this.getCurrentTwoFactorToken(),
        twoFactorProvider: this.twoFactorProvider,
        twoFactorRemember: this.twoFactorRemember ? 1 : 0
      };

      this.accessTokenResponse = await accessToken(request);
      this.successMessage = new AppText(AppTextKey.LOGIN_SUCCESS);
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      const loginError = error as LoginRequestError;
      const errorMessage = this.extractLoginErrorMessage(loginError);
      Logger.error(`Login with 2FA failed: ${errorMessage}`);
      this.handleContinuationFailure(loginError);
      return false;
    }
  }

  // 带新设备验证码的登录请求
  async performLoginWithNewDevice(): Promise<boolean> {
    try {
      const request: AccessTokenRequest = {
        grant_type: GrantType.PASSWORD,
        username: this.email.trim().toLowerCase(),
        password: this.loginPassword,
        scope: SCOPE_KEY,
        client_id: Header_Client_Name,
        deviceType: this.deviceType,
        deviceIdentifier: this.deviceIdentifier,
        deviceName: this.deviceName,
        newDeviceOtp: this.twoFactorToken.trim(),
      };

      this.accessTokenResponse = await accessToken(request);
      this.successMessage = new AppText(AppTextKey.LOGIN_SUCCESS);
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      const loginError = error as LoginRequestError;
      const errorMessage = this.extractLoginErrorMessage(loginError);
      Logger.error(`Login with new device failed: ${errorMessage}`);
      this.handleContinuationFailure(loginError);
      return false;
    }
  }

  private applyRememberedTwoFactor(request: AccessTokenRequest): void {
    // “记住我”令牌存放在加密数据库中，只在首次令牌请求时按专用 provider 回传
    const rememberedToken = CredentialStore.rememberedTwoFactorSync(
      CredentialStore.ownerKey(this.serverType, this.getNormalizedServerAddress(), this.email));
    if (!rememberedToken) {
      return;
    }

    request.twoFactorToken = rememberedToken;
    request.twoFactorProvider = TwoFactorProvider.REMEMBER;
    request.twoFactorRemember = 0;
  }

  private isTwoFactorRequired(errorData?: LoginErrorResponseData): boolean {
    return LoginErrorUtil.isTwoFactorRequired(errorData);
  }

  private isNewDeviceVerificationRequired(errorData?: LoginErrorResponseData): boolean {
    return LoginErrorUtil.isNewDeviceVerificationRequired(errorData);
  }

  private handleTwoFactorRequired(errorData?: LoginErrorResponseData): void {
    this.ssoEmail2FaSessionToken = errorData?.SsoEmail2faSessionToken ?? '';
    this.twoFactorProvidersData = errorData?.TwoFactorProviders2 ?? null;
    this.availableTwoFactorProviders = this.parseSupportedTwoFactorProviders(errorData);
    if (this.availableTwoFactorProviders.length === 0) {
      this.errorMessage = new AppText(AppTextKey.TWO_FACTOR_UNSUPPORTED);
      this.needTwoFactor = false;
      return;
    }

    this.twoFactorProvider = this.availableTwoFactorProviders[0];
    this.twoFactorProviderData = this.getTwoFactorProviderData(errorData, this.twoFactorProvider);
    this.twoFactorToken = '';
    this.needTwoFactor = true;
  }

  private parseSupportedTwoFactorProviders(errorData?: LoginErrorResponseData): number[] {
    const rawProviders = this.parseRawTwoFactorProviders(errorData);
    const supportedProviders: number[] = [];
    const preferredOrder: number[] = [
      TwoFactorProvider.AUTHENTICATOR_APP,
      TwoFactorProvider.EMAIL,
      TwoFactorProvider.WEB_AUTHN
    ];

    for (let i = 0; i < preferredOrder.length; i++) {
      const provider = preferredOrder[i];
      if (rawProviders.includes(provider) && this.isSupportedTwoFactorProvider(provider, errorData)) {
        supportedProviders.push(provider);
      }
    }

    return supportedProviders;
  }

  private isSupportedTwoFactorProvider(provider: number, errorData?: LoginErrorResponseData): boolean {
    if (provider === TwoFactorProvider.AUTHENTICATOR_APP || provider === TwoFactorProvider.EMAIL) {
      return true;
    }

    if (provider === TwoFactorProvider.WEB_AUTHN) {
      return this.hasNativePasskeyChallenge(this.getTwoFactorProviderData(errorData, provider));
    }

    return false;
  }

  private hasNativePasskeyChallenge(providerData: TwoFactorProviderData | null): boolean {
    if (!providerData) {
      return false;
    }

    const challenge = providerData['challenge'] ?? providerData['Challenge'];
    return typeof challenge === 'string' && challenge.length > 0;
  }

  private parseRawTwoFactorProviders(errorData?: LoginErrorResponseData): number[] {
    return LoginErrorUtil.providers(errorData);
  }

  private getTwoFactorProviderData(
    errorData: LoginErrorResponseData | undefined,
    provider: number
  ): TwoFactorProviderData | null {
    const providers = errorData?.TwoFactorProviders2;
    if (!providers) {
      return null;
    }

    return providers[provider.toString()] ?? null;
  }

  setTwoFactorProvider(provider: number): void {
    if (!this.availableTwoFactorProviders.includes(provider)) {
      return;
    }

    this.twoFactorProvider = provider;
    this.twoFactorProviderData = this.twoFactorProvidersData?.[provider.toString()] ?? null;
    this.twoFactorToken = '';
  }

  private getCurrentTwoFactorToken(): string {
    if (this.twoFactorProvider === TwoFactorProvider.WEB_AUTHN) {
      // 通行密钥令牌是完整 JSON，不能像人工输入的验证码一样裁剪内容
      return this.twoFactorToken;
    }

    return this.twoFactorToken.trim();
  }

  async performPasskeyTwoFactor(context: common.Context): Promise<boolean> {
    if (this.twoFactorProvider !== TwoFactorProvider.WEB_AUTHN) {
      this.errorMessage = new AppText(AppTextKey.PASSKEY_FAILED);
      return false;
    }

    if (this.passkeyChallengeNeedsRefresh) {
      const selectedProvider = this.twoFactorProvider;
      this.needTwoFactor = false;
      this.availableTwoFactorProviders = [];
      this.twoFactorProviderData = null;
      // 上次响应可能已消耗服务端挑战。重新获取后再调系统凭据接口。
      await this.performLogin();
      if (!this.needTwoFactor || !this.availableTwoFactorProviders.includes(selectedProvider)) {
        this.errorMessage = this.errorMessage ?? new AppText(AppTextKey.PASSKEY_FAILED);
        return false;
      }
      this.setTwoFactorProvider(selectedProvider);
      this.passkeyChallengeNeedsRefresh = false;
    }
    if (!this.twoFactorProviderData) {
      this.errorMessage = new AppText(AppTextKey.PASSKEY_FAILED);
      return false;
    }

    try {
      // 无论本地认证或后续服务端验证在哪一步失败，下次均获取新挑战。
      this.passkeyChallengeNeedsRefresh = true;
      this.twoFactorToken = await PasskeyTwoFactorUtil.authenticate(
        context,
        this.twoFactorProviderData,
        await this.getFallbackRpId()
      );
      return true;
    } catch (error) {
      Logger.error(`Passkey two factor failed: ${error}`);
      this.errorMessage = new AppText(AppTextKey.PASSKEY_FAILED);
      return false;
    }
  }

  private async getFallbackRpId(): Promise<string> {
    const endpoints = await getServerEndpoints();
    const match = endpoints.vaultBaseUrl.match(/^https?:\/\/([^\/:?#]+)/i);
    return match ? match[1] : '';
  }

  /**
   * 串行执行预登录、密钥派生和令牌请求，任一步失败都停止后续敏感操作
   */
  async login(): Promise<boolean> {
    // 清除之前的错误信息
    this.errorMessage = undefined;
    this.successMessage = undefined;

    // 验证输入
    if (!this.validateInput()) {
      return false;
    }

    // 保存服务器配置
    await this.saveServerConfig();

    try {
      await CredentialStore.ready();
      // 执行预登录
      const preloginSuccess = await this.performPrelogin();
      if (!preloginSuccess) {
        return false;
      }

      // 派生主密钥
      const masterKeySuccess = await this.deriveMasterKey();
      if (!masterKeySuccess) {
        return false;
      }

      // 主密钥哈希
      if (!await this.hashMasterKey()) {
        return false;
      }

      // 执行登录
      let loginSuccess: boolean = false;
      if (this.needTwoFactor) {
        loginSuccess = await this.performLoginWith2FA();
      } else if (this.needNewDevice) {
        loginSuccess = await this.performLoginWithNewDevice();
      } else {
        loginSuccess = await this.performLogin();
      }
      if (loginSuccess) {
        // 登录成功，保存登录信息
        return await this.saveLoginInfo();
      }
      return false;
    } catch (error) {
      Logger.error(`Login process failed: ${error}`);
      this.errorMessage = new AppText(AppTextKey.LOGIN_FAILED);
      return false;
    }
  }

  async continueLogin(): Promise<boolean> {
    this.errorMessage = undefined;
    try {
      let loginSuccess: boolean = false;
      if (this.needTwoFactor) {
        loginSuccess = await this.performLoginWith2FA();
      } else if (this.needNewDevice) {
        loginSuccess = await this.performLoginWithNewDevice();
      } else {
        this.errorMessage = new AppText(AppTextKey.VERIFICATION_REQUIRED);
        return false;
      }
      if (!loginSuccess) {
        return false;
      }
      return await this.saveLoginInfo();
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Login continuation failed: ${errorMessage}`);
      this.errorMessage = new AppText(AppTextKey.LOGIN_FAILED);
      return false;
    }
  }

  /**
   * 校验解密材料后，在同一个数据库事务中替换凭据及 KDF 参数
   */
  private async saveLoginInfo(): Promise<boolean> {
    this.successMessage = undefined;
    try {
      const authentication = this.getAuthenticationKdf();
      const material = LoginResponseUtil.normalize(this.accessTokenResponse, authentication, this.email);
      const unlockMasterKey = LoginResponseUtil.sameKdf(authentication, material.params) ? this.masterKey :
        await CryptoUtil.deriveMasterKey(this.password, material.params);
      await CryptoUtil.decryptUserKey(material.encryptedUserKey, unlockMasterKey);
      // 校验完成后才提交凭据事务，失败响应不会覆盖现有账号凭据。
      await this.persistLoginInfo(material, unlockMasterKey);
      this.successMessage = new AppText(AppTextKey.LOGIN_SUCCESS);
      Logger.info(`Login credentials saved: decryptionSource=${material.source}, ` +
        `KDF type=${material.params.kdf}, userKeyVerified=true`);
      return true;
    } catch (error) {
      const message = (error as Error).message;
      Logger.error(`Login credential initialization failed: ${message}`);
      if (message === PASSWORD_RESET_REQUIRED) {
        this.errorMessage = new AppText(AppTextKey.PASSWORD_RESET_REQUIRED);
      } else if (message === 'argon2_resources_unavailable') {
        this.errorMessage = new AppText(AppTextKey.KDF_RESOURCES_UNAVAILABLE);
      } else if (message === DECRYPTION_UNSUPPORTED || message === 'Unsupported user key length') {
        this.errorMessage = new AppText(AppTextKey.DECRYPTION_UNSUPPORTED);
      } else {
        this.errorMessage = new AppText(AppTextKey.ENCRYPTION_ERROR);
      }
      return false;
    }
  }

  private async persistLoginInfo(material: LoginDecryptionMaterial, unlockMasterKey: string): Promise<void> {
    const owner = CredentialStore.ownerKey(this.serverType, this.getNormalizedServerAddress(), this.email);
    const values: Record<string, string> = {};
    values[ACCESS_TOKEN_KEY] = this.accessTokenResponse.access_token;
    values[REFRESH_TOKEN_KEY] = this.accessTokenResponse.refresh_token;
    values[TOKEN_EXPIRE_TIME_KEY] = String(Math.floor(Date.now() / 1000) + this.accessTokenResponse.expires_in);
    values[TWO_FACTOR_TOKEN_KEY] = this.accessTokenResponse.TwoFactorToken ??
      CredentialStore.rememberedTwoFactorSync(owner);
    values[MASTER_KEY] = unlockMasterKey;
    values[PRIVATE_KEY] = material.encryptedPrivateKey ?? '';
    values[USER_KEY] = material.encryptedUserKey;
    values[KDF_PARAM_KEY] = JSON.stringify(material.params);
    values[EMAIL_KEY] = this.email.trim().toLowerCase();
    // 整组凭据与登录状态一起提交；写入失败会回滚到原有完整记录。
    await CredentialStore.replaceLogin(values, owner);
    this.needTwoFactor = false;
    this.needNewDevice = false;
    this.twoFactorToken = '';
    this.availableTwoFactorProviders = [];
    this.twoFactorProviderData = null;
    this.twoFactorProvidersData = null;
  }
  private extractLoginErrorMessage(error: LoginRequestError): string {
    const errorData = error.response?.data;
    if (LoginErrorUtil.isInvalidCredentials(errorData)) {
      return 'invalid_credentials';
    }

    const serverMessage = this.getErrorModelMessage(errorData) || errorData?.message || errorData?.error_description;
    if (serverMessage && serverMessage.length > 0) {
      return serverMessage;
    }

    if (error.message && error.message.length > 0) {
      return error.message;
    }

    return 'login_failed';
  }

  private handleContinuationFailure(error: LoginRequestError): void {
    const data = error.response?.data;
    if (this.isTwoFactorRequired(data)) {
      const selectedProvider = this.twoFactorProvider;
      this.needNewDevice = false;
      this.handleTwoFactorRequired(data);
      if (!this.needTwoFactor) {
        return;
      }
      if (this.availableTwoFactorProviders.includes(selectedProvider)) {
        this.setTwoFactorProvider(selectedProvider);
      }
    } else if (this.isNewDeviceVerificationRequired(data)) {
      this.needTwoFactor = false;
      this.needNewDevice = true;
      this.twoFactorToken = '';
    }
    this.errorMessage = this.getContinuationError(error);
  }

  private getContinuationError(error: LoginRequestError): AppText {
    return new AppText(LoginErrorUtil.classify(error));
  }

  private getErrorModelMessage(errorData?: LoginErrorResponseData): string {
    return LoginErrorUtil.getModelMessage(errorData);
  }

  // 清除错误信息
  clearError(): void {
    this.errorMessage = undefined;
  }

  // 清除成功信息
  clearSuccess(): void {
    this.successMessage = undefined;
  }

  // 复制当前状态到新的实例
  clone(): LoginViewModel {
    const newViewModel = new LoginViewModel();
    newViewModel.email = this.email;
    newViewModel.password = this.password;
    newViewModel.serverAddress = this.serverAddress;
    newViewModel.serverType = this.serverType;
    newViewModel.errorMessage = this.errorMessage;
    newViewModel.successMessage = this.successMessage;
    newViewModel.kdfType = this.kdfType;
    newViewModel.kdfIterations = this.kdfIterations;
    newViewModel.kdfMemory = this.kdfMemory;
    newViewModel.kdfParallelism = this.kdfParallelism;
    newViewModel.kdfSalt = this.kdfSalt;
    newViewModel.masterKey = this.masterKey;
    newViewModel.loginPassword = this.loginPassword;
    newViewModel.deviceType = this.deviceType;
    newViewModel.deviceIdentifier = this.deviceIdentifier;
    newViewModel.deviceName = this.deviceName;
    newViewModel.deviceInfoInitialized = this.deviceInfoInitialized;
    newViewModel.passkeyChallengeNeedsRefresh = this.passkeyChallengeNeedsRefresh;
    newViewModel.needTwoFactor = this.needTwoFactor;
    newViewModel.needNewDevice = this.needNewDevice;
    newViewModel.needSaveEmail = this.needSaveEmail;
    newViewModel.accessTokenResponse = this.accessTokenResponse;
    newViewModel.twoFactorProvider = this.twoFactorProvider;
    newViewModel.availableTwoFactorProviders = this.availableTwoFactorProviders;
    newViewModel.twoFactorProviderData = this.twoFactorProviderData;
    newViewModel.twoFactorProvidersData = this.twoFactorProvidersData;
    newViewModel.ssoEmail2FaSessionToken = this.ssoEmail2FaSessionToken;
    newViewModel.twoFactorRemember = this.twoFactorRemember;
    newViewModel.twoFactorToken = this.twoFactorToken;
    return newViewModel;
  }

  // 重置所有状态
  reset(): void {
    this.email = '';
    this.password = '';
    this.serverAddress = '';
    this.serverType = ServerType.US;
    this.errorMessage = undefined;
    this.successMessage = undefined;
    this.kdfType = 0;
    this.kdfIterations = 0;
    this.kdfMemory = 0;
    this.kdfParallelism = 0;
    this.kdfSalt = '';
    this.masterKey = '';
    this.loginPassword = '';
    this.needTwoFactor = false;
    this.needNewDevice = false;
    this.twoFactorToken = '';
    this.twoFactorRemember = false;
    this.twoFactorProvider = TwoFactorProvider.AUTHENTICATOR_APP;
    this.availableTwoFactorProviders = [];
    this.twoFactorProviderData = null;
    this.twoFactorProvidersData = null;
    this.ssoEmail2FaSessionToken = '';
    this.passkeyChallengeNeedsRefresh = false;
  }

  // 清理敏感数据
  clearSensitiveData(): void {
    // 清理密码和密钥
    this.password = '';
    this.masterKey = '';
    this.loginPassword = '';

    Logger.info('Sensitive data cleared from LoginViewModel');
  }

  // 保存服务器配置
  private async saveServerConfig(): Promise<void> {
    try {
      const serverType = this.getValidServerType();
      DataPreferences.getInstance().putSync(SERVER_TYPE_KEY, serverType);
      DataPreferences.getInstance().putSync(SERVER_ADDRESS_KEY, this.getNormalizedServerAddress());
    } catch (error) {
      Logger.error("failed to save server config, error message: " + error);
    }
  }

  private getValidServerType(): ServerType {
    if (this.serverType === ServerType.US ||
      this.serverType === ServerType.EU ||
      this.serverType === ServerType.SELF_HOSTED) {
      return this.serverType;
    }

    return ServerType.US;
  }

  private getNormalizedServerAddress(): string {
    return this.serverAddress ? this.serverAddress.trim() : '';
  }

  // 读取服务器配置
  async loadServerConfig(): Promise<void> {
    const serverConfig = await getServerConfig();
    this.serverType = serverConfig.serverType;
    this.serverAddress = serverConfig.serverAddress;
  }

  async doSendEmailLogin(): Promise<boolean> {
    try {
      await this.initializeAsyncDeviceInfo();
      const request: SendEmailLoginRequest = {
        DeviceIdentifier: this.deviceIdentifier,
        Email: this.email.trim().toLowerCase(),
        MasterPasswordHash: this.loginPassword,
        SsoEmail2FaSessionToken: this.ssoEmail2FaSessionToken
      }
      return await sendEmailLogin(request);
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Send email login failed: ${errorMessage}`);
      const key = LoginErrorUtil.classify(error as LoginRequestError);
      this.errorMessage = new AppText(key === AppTextKey.LOGIN_FAILED ? AppTextKey.CODE_SEND_FAILED : key);
      return false;
    }
  }

  async doResendNewDeviceOtp(): Promise<boolean> {
    try {
      await this.initializeAsyncDeviceInfo();
      const request: ResendNewDeviceOtpRequest = {
        Email: this.email.trim().toLowerCase(),
        MasterPasswordHash: this.loginPassword
      }
      return await resendNewDeviceOtp(request, this.deviceIdentifier);
    } catch (error) {
      const errorMessage = ErrorMessageUtil.getMessage(error as Object);
      Logger.error(`Resend new device OTP failed: ${errorMessage}`);
      const key = LoginErrorUtil.classify(error as LoginRequestError);
      this.errorMessage = new AppText(key === AppTextKey.LOGIN_FAILED ? AppTextKey.CODE_SEND_FAILED : key);
      return false;
    }
  }
}
