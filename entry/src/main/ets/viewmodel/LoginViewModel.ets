import { accessToken, prelogin, resendNewDeviceOtp, sendEmailLogin } from '../network/AuthApi';
import {
  ACCESS_TOKEN_KEY_1,
  ACCESS_TOKEN_KEY_2,
  DeviceType,
  EMAIL_KEY,
  GrantType,
  Header_Client_Name,
  KDF_PARAM_KEY,
  LOGIN_STATUS_KEY,
  MASTER_KEY,
  PRIVATE_KEY_1,
  PRIVATE_KEY_2,
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
import { addAsset, deleteAsset, queryAssetSync, updateAsset } from '../utils/AssetUtil';
import { AssetModel } from '../model/AssetModel';
import { asset } from '@kit.AssetStoreKit';
import { getServerConfig } from '../network/HttpClient';
import { AccessTokenRequest, AccessTokenResponse, TwoFactorProvider, TwoFactorProviderData } from '../model/AccessToken';
import { PreloginRequest, PreloginResponse } from '../model/Prelogin';
import { ResendNewDeviceOtpRequest, SendEmailLoginRequest } from '../model/SendEmailLogin';
import { PasskeyTwoFactorUtil } from '../utils/PasskeyTwoFactorUtil';
import { common } from '@kit.AbilityKit';
import { getServerEndpoints } from '../network/ServerEndpointResolver';

interface LoginErrorModel {
  Message?: string;
  message?: string;
  Object?: string;
}

interface LoginErrorResponseData {
  error?: string;
  error_description?: string;
  message?: string;
  ErrorModel?: LoginErrorModel;
  errorModel?: LoginErrorModel;
  TwoFactorProviders?: string[] | string;
  TwoFactorProviders2?: Record<string, TwoFactorProviderData | null>;
  SsoEmail2faSessionToken?: string;
}

interface LoginErrorResponse {
  data?: LoginErrorResponseData;
}

interface LoginRequestError {
  message?: string;
  response?: LoginErrorResponse;
}

/**
 * 登录界面ViewModel
 */
export class LoginViewModel {
  // 登录状态
  email: string = '';
  needSaveEmail: boolean = false;
  password: string = '';
  serverAddress: string = '';
  serverType: ServerType = ServerType.US;
  errorMessage: string = '';
  successMessage: string = '';
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
  kdfType: number = 0; // 0=PBKDF2, 1=Argon2id
  kdfIterations: number = 0;
  kdfMemory: number = 0;
  kdfParallelism: number = 0;
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
        Logger.info(`Device info initialized: type=${this.deviceType}, name=${this.deviceName}, id=${this.deviceIdentifier}`);
      } catch (error) {
        Logger.error(`Failed to initialize device info: ${error}`);
        // 如果获取失败，使用临时生成的UUID
        this.deviceIdentifier = DeviceUtil.generateUUID();
        this.deviceInfoInitialized = true;
      }
    }
  }

  // 验证输入
  validateInput(): boolean {
    if (!this.email || !this.email.trim()) {
      this.errorMessage = '请输入邮箱地址';
      return false;
    }

    if (!this.password || !this.password.trim()) {
      this.errorMessage = '请输入密码';
      return false;
    }

    if (this.serverType === ServerType.SELF_HOSTED && !this.getNormalizedServerAddress()) {
      this.errorMessage = '请输入自托管服务器地址';
      return false;
    }

    return true;
  }

  // 预登录
  async performPrelogin(): Promise<boolean> {
    try {
      // 先查询是否存在Asset
      const queryResult = queryAssetSync(EMAIL_KEY);
      if (queryResult) {
        updateAsset(EMAIL_KEY, asset.Tag.SECRET, this.email);
      } else {
        const emailAsset: AssetModel = { alias: EMAIL_KEY, secret: this.email };
        addAsset(emailAsset);
      }
      const request: PreloginRequest = {
        email: this.email.trim().toLowerCase()
      };
      const response: PreloginResponse = await prelogin(request);

      this.kdfType = response.kdf;
      this.kdfIterations = response.kdfIterations;
      this.kdfMemory = response.kdfMemory;
      this.kdfParallelism = response.kdfParallelism;

      Logger.info(`Prelogin successful: KDF type=${this.kdfType}, iterations=${this.kdfIterations}, memory=${this.kdfMemory}, parallelism=${this.kdfParallelism}`);
      return true;
    } catch (error) {
      Logger.error(`Prelogin failed: ${error}`);
      this.errorMessage = '预登录失败，请检查网络连接和服务器地址';
      return false;
    }
  }

  // 派生主密钥
  async deriveMasterKey(): Promise<boolean> {
    try {
      const salt = this.email.trim().toLowerCase();

      if (this.kdfType === 0) {
        // PBKDF2
        this.masterKey = await CryptoUtil.deriveKeyPBKDF2(
          this.password,
          salt,
          this.kdfIterations,
          32
        );
      } else if (this.kdfType === 1) {
        // Argon2id
        this.masterKey = await CryptoUtil.deriveKeyArgon2id(
          this.password,
          salt,
          this.kdfIterations,
          this.kdfMemory,
          this.kdfParallelism,
          32
        );
      } else {
        this.errorMessage = '不支持的KDF类型';
        return false;
      }

      Logger.info('Master key derived successfully');
      return true;
    } catch (error) {
      Logger.error(`Master key derivation failed: ${error}`);
      this.errorMessage = '主密钥派生失败';
      return false;
    }
  }

  // 二次派生，生成登录时发送给服务器的密码
  async hashMasterKey(): Promise<boolean> {
    try {
      // 将Base64主密钥解码为Uint8Array
      const masterKeyBytes = new util.Base64Helper().decodeSync(this.masterKey);
      this.loginPassword = await CryptoUtil.deriveKeyPBKDF2(
        masterKeyBytes,
        this.password,
        1,
        32
      );
      Logger.info('Hash master key successfully');
      return true;
    } catch (error) {
      Logger.error(`Master key hash failed: ${error}`);
      this.errorMessage = '主密钥哈希失败';
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
      this.successMessage = '登录成功！';
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
      this.errorMessage = `登录失败，错误信息：${errorMessage}`;
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
      this.successMessage = '登录成功！';
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      const errorMessage = this.extractLoginErrorMessage(error as LoginRequestError);
      Logger.error(`Login with 2FA failed: ${errorMessage}`);
      this.errorMessage = `登录失败，错误信息：${errorMessage}`;
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
      this.successMessage = '登录成功！';
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      const errorMessage = this.extractLoginErrorMessage(error as LoginRequestError);
      Logger.error(`Login with new device failed: ${errorMessage}`);
      this.errorMessage = `登录失败，错误信息：${errorMessage}`;
      return false;
    }
  }

  private applyRememberedTwoFactor(request: AccessTokenRequest): void {
    const rememberedToken = queryAssetSync(TWO_FACTOR_TOKEN_KEY);
    if (!rememberedToken) {
      return;
    }

    request.twoFactorToken = rememberedToken;
    request.twoFactorProvider = TwoFactorProvider.REMEMBER;
    request.twoFactorRemember = 0;
  }

  private isTwoFactorRequired(errorData?: LoginErrorResponseData): boolean {
    if (errorData?.TwoFactorProviders2) {
      return true;
    }

    return errorData?.error === 'invalid_grant' &&
      errorData?.error_description === 'Two factor required.';
  }

  private isNewDeviceVerificationRequired(errorData?: LoginErrorResponseData): boolean {
    if (errorData?.error === 'device_error') {
      return true;
    }

    return this.getErrorModelMessage(errorData).toLowerCase() === 'new device verification required';
  }

  private handleTwoFactorRequired(errorData?: LoginErrorResponseData): void {
    this.ssoEmail2FaSessionToken = errorData?.SsoEmail2faSessionToken ?? '';
    this.twoFactorProvidersData = errorData?.TwoFactorProviders2 ?? null;
    this.availableTwoFactorProviders = this.parseSupportedTwoFactorProviders(errorData);
    if (this.availableTwoFactorProviders.length === 0) {
      this.errorMessage = '当前账号启用了不受支持的两步验证方式';
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
    if (errorData?.TwoFactorProviders2) {
      return Object.keys(errorData.TwoFactorProviders2)
        .map((provider: string) => Number(provider))
        .filter((provider: number) => !Number.isNaN(provider));
    }

    const providers = errorData?.TwoFactorProviders;
    if (Array.isArray(providers)) {
      return providers
        .map((provider: string) => Number(provider))
        .filter((provider: number) => !Number.isNaN(provider));
    }

    if (typeof providers === 'string') {
      const matches = providers.match(/-?\d+/g) ?? [];
      return matches
        .map((provider: string) => Number(provider))
        .filter((provider: number) => !Number.isNaN(provider));
    }

    return [];
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
      return this.twoFactorToken;
    }

    return this.twoFactorToken.trim();
  }

  async performPasskeyTwoFactor(context: common.Context): Promise<boolean> {
    if (this.twoFactorProvider !== TwoFactorProvider.WEB_AUTHN) {
      this.errorMessage = '当前两步验证方式不是通行密钥';
      return false;
    }

    if (!this.twoFactorProviderData) {
      this.errorMessage = '服务端未返回可用的通行密钥验证数据';
      return false;
    }

    try {
      this.twoFactorToken = await PasskeyTwoFactorUtil.authenticate(
        context,
        this.twoFactorProviderData,
        await this.getFallbackRpId()
      );
      return true;
    } catch (error) {
      Logger.error(`Passkey two factor failed: ${error}`);
      this.errorMessage = '通行密钥验证失败，请改用验证码或重试';
      return false;
    }
  }

  private async getFallbackRpId(): Promise<string> {
    const endpoints = await getServerEndpoints();
    const match = endpoints.vaultBaseUrl.match(/^https?:\/\/([^\/:?#]+)/i);
    return match ? match[1] : '';
  }

  // 登录流程
  async login(): Promise<boolean> {
    // 清除之前的错误信息
    this.errorMessage = '';
    this.successMessage = '';

    // 验证输入
    if (!this.validateInput()) {
      return false;
    }

    // 保存服务器配置
    await this.saveServerConfig();

    try {
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
        this.saveLoginInfo();
        return true;
      }
      return false;
    } catch (error) {
      Logger.error(`Login process failed: ${error}`);
      this.errorMessage = '登录过程中发生未知错误';
      return false;
    }
  }

  // 保存登录凭据和加密参数
  private saveLoginInfo() {
    this.needTwoFactor = false;
    this.needNewDevice = false;
    this.twoFactorToken = '';
    this.availableTwoFactorProviders = [];
    this.twoFactorProviderData = null;
    this.twoFactorProvidersData = null;
    // 删除原本的凭据
    deleteAsset(MASTER_KEY);
    deleteAsset(ACCESS_TOKEN_KEY_1);
    deleteAsset(ACCESS_TOKEN_KEY_2);
    deleteAsset(REFRESH_TOKEN_KEY);
    deleteAsset(TOKEN_EXPIRE_TIME_KEY);
    deleteAsset(PRIVATE_KEY_1);
    deleteAsset(PRIVATE_KEY_2);
    deleteAsset(USER_KEY);
    deleteAsset(KDF_PARAM_KEY);
    deleteAsset(TWO_FACTOR_TOKEN_KEY);
    // 保存新的凭据
    if (this.accessTokenResponse.access_token.length > 1000) {
      addAsset(this.createAssetModel(ACCESS_TOKEN_KEY_1, this.accessTokenResponse.access_token.substring(0, 1000)));
      addAsset(this.createAssetModel(ACCESS_TOKEN_KEY_2, this.accessTokenResponse.access_token.substring(1000)));
    } else {
      addAsset(this.createAssetModel(ACCESS_TOKEN_KEY_1, this.accessTokenResponse.access_token));
    }
    addAsset(this.createAssetModel(MASTER_KEY, this.masterKey));
    if (this.accessTokenResponse.PrivateKey) {
      addAsset(this.createAssetModel(PRIVATE_KEY_1, this.accessTokenResponse.PrivateKey.substring(0, 1000)));
      addAsset(this.createAssetModel(PRIVATE_KEY_2, this.accessTokenResponse.PrivateKey.substring(1000)));
    }
    if (this.accessTokenResponse.Key) {
      addAsset(this.createAssetModel(USER_KEY, this.accessTokenResponse.Key));
    }
    addAsset(this.createAssetModel(REFRESH_TOKEN_KEY, this.accessTokenResponse.refresh_token));
    let expireTime = Math.floor(Date.now() / 1000) + this.accessTokenResponse.expires_in;
    addAsset(this.createAssetModel(TOKEN_EXPIRE_TIME_KEY, expireTime.toString()));
    if (this.accessTokenResponse.TwoFactorToken) {
      addAsset(this.createAssetModel(TWO_FACTOR_TOKEN_KEY, this.accessTokenResponse.TwoFactorToken));
    }

    // 保存后续加解密的参数
    const kdfParam: PreloginResponse = {
      kdf: this.accessTokenResponse.Kdf,
      kdfIterations: this.accessTokenResponse.KdfIterations ?? this.kdfIterations,
      kdfMemory: this.accessTokenResponse.KdfMemory ?? this.kdfMemory,
      kdfParallelism: this.accessTokenResponse.KdfParallelism ?? this.kdfParallelism
    };
    addAsset(this.createAssetModel(KDF_PARAM_KEY, JSON.stringify(kdfParam)));

    DataPreferences.getInstance().putSync(LOGIN_STATUS_KEY, 1);

    // Logger.info(`登录信息: \naccessToken: ${this.accessTokenResponse.access_token},\nrefreshToken: ${this.accessTokenResponse.refresh_token},\nexpiresIn: ${this.accessTokenResponse.expires_in},\n`)
  }

  private createAssetModel(alias: string, secret: string, label?: string[]): AssetModel {
    return {
      alias: alias,
      secret: secret,
      label: label
    }
  }

  private extractLoginErrorMessage(error: LoginRequestError): string {
    const errorData = error.response?.data;
    if (errorData?.error_description === 'invalid_username_or_password') {
      return '用户名或密码不正确，请重试';
    }

    const serverMessage = this.getErrorModelMessage(errorData) || errorData?.message || errorData?.error_description;
    if (serverMessage && serverMessage.length > 0) {
      return serverMessage;
    }

    if (error.message && error.message.length > 0) {
      return error.message;
    }

    return '请检查邮箱、密码和服务器连接后重试';
  }

  private getErrorModelMessage(errorData?: LoginErrorResponseData): string {
    return errorData?.ErrorModel?.Message ||
      errorData?.ErrorModel?.message ||
      errorData?.errorModel?.Message ||
      errorData?.errorModel?.message ||
      '';
  }

  // 清除错误信息
  clearError(): void {
    this.errorMessage = '';
  }

  // 清除成功信息
  clearSuccess(): void {
    this.successMessage = '';
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
    newViewModel.masterKey = this.masterKey;
    newViewModel.deviceType = this.deviceType;
    newViewModel.deviceIdentifier = this.deviceIdentifier;
    newViewModel.deviceName = this.deviceName;
    newViewModel.deviceInfoInitialized = this.deviceInfoInitialized;
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
    this.errorMessage = '';
    this.successMessage = '';
    this.kdfType = 0;
    this.kdfIterations = 0;
    this.kdfMemory = 0;
    this.kdfParallelism = 0;
    this.masterKey = '';
    this.needTwoFactor = false;
    this.needNewDevice = false;
    this.twoFactorToken = '';
    this.twoFactorRemember = false;
    this.twoFactorProvider = TwoFactorProvider.AUTHENTICATOR_APP;
    this.availableTwoFactorProviders = [];
    this.twoFactorProviderData = null;
    this.twoFactorProvidersData = null;
    this.ssoEmail2FaSessionToken = '';
  }

  // 清理敏感数据
  clearSensitiveData(): void {
    // 清理密码和密钥
    this.password = '';
    this.masterKey = '';

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
    // await DataPreferences.getInstance().getPromise(SERVER_ADDRESS_KEY, '').then((data: string) => {
    //   this.serverAddress = data;
    // });
    const serverConfig = await getServerConfig();
    this.serverType = serverConfig.serverType;
    this.serverAddress = serverConfig.serverAddress;
  }

  async doSendEmailLogin(): Promise<boolean> {
    await this.initializeAsyncDeviceInfo();
    if (!await this.hashMasterKey()) {
      return false;
    }
    const request: SendEmailLoginRequest = {
      DeviceIdentifier: this.deviceIdentifier,
      Email: this.email.trim().toLowerCase(),
      MasterPasswordHash: this.loginPassword,
      SsoEmail2FaSessionToken: this.ssoEmail2FaSessionToken
    }

    return await sendEmailLogin(request);
  }

  async doResendNewDeviceOtp(): Promise<boolean> {
    if (!await this.hashMasterKey()) {
      return false;
    }
    const request: ResendNewDeviceOtpRequest = {
      Email: this.email.trim().toLowerCase(),
      MasterPasswordHash: this.loginPassword
    }

    return await resendNewDeviceOtp(request);
  }
}
