import { accessToken, prelogin, sendEmailLogin } from '../network/AuthApi';
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
import { AccessTokenRequest, AccessTokenResponse } from '../model/AccessToken';
import { PreloginRequest, PreloginResponse } from '../model/Prelogin';
import { SendEmailLoginRequest } from '../model/SendEmailLogin';

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
  twoFactorProvider: number = 0;
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

    if (this.serverType === ServerType.SELF_HOSTED && !this.serverAddress.trim()) {
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

      this.accessTokenResponse = await accessToken(request);
      this.successMessage = '登录成功！';
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      // 检查是否为2FA错误
      if (error?.response?.data?.error === 'invalid_grant' &&
        error?.response?.data?.error_description === 'Two factor required.') {
        // 提取2FA方式字段
        this.twoFactorProvider = error?.response?.data?.TwoFactorProviders.includes("0") ? 0 : 1;
        this.needTwoFactor = true;
        return false;
      }
      // 检查是否需要新设备验证
      if (error?.response?.data?.error === 'device_error') {
        this.needNewDevice = true;
        return false;
      }
      Logger.error(`Login failed: ${error}`);
      this.errorMessage = `登录失败, 请检查邮箱和密码`;
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
        twoFactorToken: this.twoFactorToken,
        twoFactorProvider: this.twoFactorProvider,
        twoFactorRemember: this.twoFactorRemember ? 1 : 0
      };

      this.accessTokenResponse = await accessToken(request);
      this.successMessage = '登录成功！';
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      Logger.error(`Login failed: ${error}`);
      this.errorMessage = '登录失败，请重试';
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
        newDeviceOtp: this.twoFactorToken,
      };

      this.accessTokenResponse = await accessToken(request);
      this.successMessage = '登录成功！';
      Logger.info('Login successful, tokens received');
      return true;
    } catch (error) {
      Logger.error(`Login failed: ${error}`);
      this.errorMessage = '登录失败，请重试';
      return false;
    }
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
    this.saveServerConfig();

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
    addAsset(this.createAssetModel(PRIVATE_KEY_1, this.accessTokenResponse.PrivateKey.substring(0, 1000)));
    addAsset(this.createAssetModel(PRIVATE_KEY_2, this.accessTokenResponse.PrivateKey.substring(1000)));
    addAsset(this.createAssetModel(USER_KEY, this.accessTokenResponse.Key));
    addAsset(this.createAssetModel(REFRESH_TOKEN_KEY, this.accessTokenResponse.refresh_token));
    let expireTime = Math.floor(Date.now() / 1000) + this.accessTokenResponse.expires_in;
    addAsset(this.createAssetModel(TOKEN_EXPIRE_TIME_KEY, expireTime.toString()));
    if (this.accessTokenResponse.TwoFactorToken) {
      addAsset(this.createAssetModel(TWO_FACTOR_TOKEN_KEY, this.accessTokenResponse.TwoFactorToken));
    }

    // 保存后续加解密的参数
    const kdfParam: PreloginResponse = {
      kdf: this.accessTokenResponse.Kdf,
      kdfIterations: this.accessTokenResponse.KdfIterations,
      kdfMemory: this.accessTokenResponse.KdfMemory,
      kdfParallelism: this.accessTokenResponse.KdfParallelism
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
    DataPreferences.getInstance().put(SERVER_TYPE_KEY, this.serverType, (isSuccess: boolean, error) => {
      if (!isSuccess) {
        Logger.error("failed to save server config, error message: " + error?.message);
      }
    })
    DataPreferences.getInstance()
      .put(SERVER_ADDRESS_KEY, this.serverAddress, (isSuccess: boolean, error) => {
        if (!isSuccess) {
          Logger.error("failed to save server config, error message: " + error?.message);
        }
      })
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
    if (!await this.hashMasterKey()) {
      return false;
    }
    const request: SendEmailLoginRequest = {
      authRequestAccessCode: "",
      authRequestId: "",
      ssoEmail2FaSessionToken: "",
      deviceIdentifier
      : this.deviceIdentifier,
      email: this.email,
      masterPasswordHash: this.loginPassword
    }

    return await sendEmailLogin(request);
  }
}
