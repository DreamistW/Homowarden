import { prelogin, accessToken } from '../network/AuthApi.ets';
import { PreloginRequest } from '../model/PreloginRequest.ets';
import { PreloginResponse } from '../model/PreloginResponse.ets';
import { AccessTokenRequest } from '../model/AccessTokenRequest.ets';
import { AccessTokenResponse } from '../model/AccessTokenResponse.ets';
import { ServerType, DeviceType, SERVER_TYPE_KEY, SERVER_ADDRESS_KEY } from '../utils/Constants.ets';
import { Logger } from '@nzy/logger';
import { Crypto } from '../utils/Crypto.ets';
import { DeviceUtil } from '../utils/DeviceUtil';
import { DataPreferences } from '@abner/datastore';
import { util } from '@kit.ArkTS';

export class LoginViewModel {
  // 登录状态
  email: string = '';
  password: string = '';
  serverAddress: string = '';
  serverType: ServerType = ServerType.US;
  errorMessage: string = '';
  successMessage: string = '';
  needTwoFactor: boolean = false;
  twoFactorToken: string = '';
  // 预登录信息
  kdfType: number = 0; // 0=PBKDF2, 1=Argon2id
  kdfIterations: number = 0;
  kdfMemory: number = 0;
  kdfParallelism: number = 0;
  // 登录结果
  accessToken: string = '';
  refreshToken: string = '';
  tokenExpiresIn: number = 0;
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
        Logger.debug(`Device info initialized: type=${this.deviceType}, name=${this.deviceName}, id=${this.deviceIdentifier}`);
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
      const request: PreloginRequest = {
        email: this.email.trim()
      };
      const response: PreloginResponse = await prelogin(request);

      this.kdfType = response.kdf;
      this.kdfIterations = response.kdfIterations;
      this.kdfMemory = response.kdfMemory;
      this.kdfParallelism = response.kdfParallelism;

      Logger.debug(`Prelogin successful: KDF type=${this.kdfType}, iterations=${this.kdfIterations}, memory=${this.kdfMemory}, parallelism=${this.kdfParallelism}`);
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
        this.masterKey = await Crypto.deriveKeyPBKDF2(
          this.password,
          salt,
          this.kdfIterations,
          32
        );
      } else if (this.kdfType === 1) {
        // Argon2id
        this.masterKey = await Crypto.deriveKeyArgon2id(
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

      Logger.debug('Master key derived successfully');
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
      const masterKeyBytes = new util.Base64Helper().decodeSync(this.masterKey, util.Type.BASIC);
      this.loginPassword = await Crypto.deriveKeyPBKDF2(
        masterKeyBytes,
        this.password,
        1,
        32
      );
      Logger.debug('Hash master key successfully');
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
        grant_type: 'password',
        username: this.email.trim(),
        password: this.loginPassword,
        scope: 'api offline_access',
        client_id: 'web',
        deviceType: this.deviceType,
        deviceIdentifier: this.deviceIdentifier,
        deviceName: this.deviceName
      };

      const response: AccessTokenResponse = await accessToken(request);

      this.accessToken = response.access_token;
      this.refreshToken = response.refresh_token;
      this.tokenExpiresIn = response.expires_in;

      this.successMessage = '登录成功！';
      Logger.debug('Login successful, tokens received');
      return true;
    } catch (error) {
      // 检查是否为2FA错误
      if (error?.response?.data?.error === 'invalid_grant' &&
        error?.response?.data?.error_description === 'Two factor required.') {
        this.needTwoFactor = true;
        return false;
      }
      Logger.error(`Login failed: ${error}`);
      this.errorMessage = '登录失败，请检查邮箱和密码';
      return false;
    }
  }

  // 带2FA的登录请求
  async performLoginWith2FA(): Promise<boolean> {
    try {
      const request: AccessTokenRequest = {
        grant_type: 'password',
        username: this.email.trim(),
        password: this.loginPassword,
        scope: 'api offline_access',
        client_id: 'web',
        deviceType: this.deviceType,
        deviceIdentifier: this.deviceIdentifier,
        deviceName: this.deviceName,
        two_factor_token: this.twoFactorToken,
        two_factor_provider: 0,
        twoFactorRemember: 0
      };
      const response: AccessTokenResponse = await accessToken(request);
      this.accessToken = response.access_token;
      this.refreshToken = response.refresh_token;
      this.tokenExpiresIn = response.expires_in;

      this.successMessage = '登录成功！';
      Logger.debug('Login successful, tokens received');
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

  // 保存登录信息到本地存储
  private saveLoginInfo(): void {
    // TODO: 实现本地存储逻辑
    // 可以使用preferences或kvStore来保存token等信息
    Logger.debug(`登录信息: \naccessToken: ${this.accessToken},\nrefreshToken: ${this.refreshToken},\nexpiresIn: ${this.tokenExpiresIn},\nserverType: ${this.serverType},\nserverAddress: ${this.serverAddress},\ndeviceType: ${this.deviceType} (${DeviceUtil.getDeviceTypeDescription(this.deviceType)}),\ndeviceIdentifier: ${this.deviceIdentifier},\ndeviceName: ${this.deviceName}`)
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
    newViewModel.accessToken = this.accessToken;
    newViewModel.refreshToken = this.refreshToken;
    newViewModel.tokenExpiresIn = this.tokenExpiresIn;
    newViewModel.masterKey = this.masterKey;
    newViewModel.deviceType = this.deviceType;
    newViewModel.deviceIdentifier = this.deviceIdentifier;
    newViewModel.deviceName = this.deviceName;
    newViewModel.deviceInfoInitialized = this.deviceInfoInitialized;
    newViewModel.needTwoFactor = this.needTwoFactor;
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
    this.accessToken = '';
    this.refreshToken = '';
    this.tokenExpiresIn = 0;
    this.masterKey = '';
    // 设备信息不需要重置，保持一致性
  }

  // 清理敏感数据
  clearSensitiveData(): void {
    // 清理密码和密钥
    this.password = '';
    this.masterKey = '';
    this.accessToken = '';
    this.refreshToken = '';

    Logger.debug('Sensitive data cleared from LoginViewModel');
  }

  // 保存服务器配置到DataStore
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

  // 从DataPreferences读取服务器配置
  async loadServerConfig(): Promise<void> {
    await DataPreferences.getInstance().getPromise(SERVER_TYPE_KEY, ServerType.US).then((data: ServerType) => {
      this.serverType = data;
    })
    await DataPreferences.getInstance().getPromise(SERVER_ADDRESS_KEY, '').then((data: string) => {
      this.serverAddress = data;
    });
  }
}
