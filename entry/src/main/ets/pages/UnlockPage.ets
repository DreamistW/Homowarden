import { EntryRouter } from '../../../../EntryRouter';
import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { IBestToast } from '@ibestservices/ibest-ui';
import { DataPreferences } from '@abner/datastore';
import {
  BACKGROUND_TIMESTAMP,
  BIOMETRIC_AUTH,
  EMAIL_KEY,
  KDF_PARAM_KEY,
  MASTER_KEY
} from '../utils/Constants';
import { Logger } from '@nzy/logger';
import { clearAssetAndPreferences, queryAssetSync } from '../utils/AssetUtil';
import { PreloginResponse } from '../model/Prelogin';
import { CryptoUtil } from '../utils/CryptoUtil';

@Builder
export function UnlockPageBuilder() {
  UnlockPage();
}

@Component
export struct UnlockPage {
  pathInfos: NavPathStack = new NavPathStack();
  private exitTime: number = 0;
  private masterPassword: string = "";

  aboutToAppear() {
    if (DataPreferences.getInstance().getSync<number>(BIOMETRIC_AUTH) == 1) {
      // 自动拉起生物认证
      this.startBiometricAuth();
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 应用图标
        Image($r('app.media.app_small_icon'))
          .width(120)
          .height(120)
          .margin({ top: 100, bottom: 40 })

        // 应用名称
        Text($r('app.string.app_name'))
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 80 })

        Text('密码库已锁定, 请输入主密码')
          .fontSize(14)
          .fontColor('#666666')
          .margin({
            left: 16,
            right: 16,
            top: 12,
            bottom: 4
          })
        TextInput({ text: this.masterPassword })
          .onChange((v: string) => {
            this.masterPassword = v;
          })
          .margin({ left: 16, right: 16, bottom: 24 })
          .type(InputType.Password)

        // 密码解锁按钮
        Button() {
          Text('主密码解锁')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .width(200)
        .height(50)
        .backgroundColor('#007DFF')
        .borderRadius(25)
        .onClick(() => {
          // 主密码解锁
          this.startPasswordAuth();
        })
        .margin({ bottom: 24 })

        // 生物解锁按钮
        Button() {
          Text('生物识别解锁')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .width(200)
        .height(50)
        .backgroundColor('#007DFF')
        .borderRadius(25)
        .onClick(() => {
          if (DataPreferences.getInstance().getSync<number>(BIOMETRIC_AUTH) == 1) {
            // 点击解锁按钮拉起生物认证
            this.startBiometricAuth();
          } else {
            IBestToast.show('未开启生物识别');
          }
        })
        .margin({ bottom: 24 })

        // 注销按钮
        Button() {
          Text('注销')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .width(200)
        .height(50)
        .backgroundColor('#007DFF')
        .borderRadius(25)
        .onClick(() => {
          clearAssetAndPreferences();
          // 跳转到登录页面
          this.pathInfos.replacePath({ name: EntryRouter.LoginPage });
        })

        Blank()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
    }
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .hideBackButton(true).onBackPressed(() => {
      const currentTime = new Date().getTime();
      if (currentTime - this.exitTime < 2000) {
        (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
      } else {
        this.exitTime = currentTime;
        this.getUIContext().getPromptAction().showToast({
          message: "再按一次退出"
        });
      }
      return true;
    })
  }

  async startPasswordAuth() {
    if (!this.masterPassword || this.masterPassword.length === 0) {
      IBestToast.show('请输入主密码');
      return;
    }

    try {
      // 获取存储的 KDF 参数
      const kdfParamStr: string = queryAssetSync(KDF_PARAM_KEY);

      if (!kdfParamStr) {
        IBestToast.show('获取参数失败, 请重新登录');
        this.pathInfos.replacePath({ name: "LoginPage" });
      }

      const kdfParams: PreloginResponse = JSON.parse(kdfParamStr);
      const storedMasterKey = queryAssetSync(MASTER_KEY);
      const email = queryAssetSync(EMAIL_KEY);
      if (!storedMasterKey) {
        IBestToast.show('获取参数失败, 请重新登录');
        this.pathInfos.replacePath({ name: "LoginPage" });
      }

      // 使用输入的密码重新派生主密钥
      let derivedMasterKey: string = '';
      const salt = email.trim().toLowerCase() || '';

      if (kdfParams.kdf === 0) {
        // PBKDF2
        derivedMasterKey = await CryptoUtil.deriveKeyPBKDF2(
          this.masterPassword,
          salt,
          kdfParams.kdfIterations || 100000,
          32
        );
      } else if (kdfParams.kdf === 1) {
        // Argon2id
        derivedMasterKey = await CryptoUtil.deriveKeyArgon2id(
          this.masterPassword,
          salt,
          kdfParams.kdfIterations || 2,
          kdfParams.kdfMemory || 16,
          kdfParams.kdfParallelism || 1,
          32
        );
      } else {
        IBestToast.show('获取参数失败, 请重新登录');
        this.pathInfos.replacePath({ name: "LoginPage" });
      }

      // 验证派生的主密钥是否与存储的匹配
      if (derivedMasterKey === storedMasterKey) {
        DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
        const info: NavPathInfo[] = this.pathInfos.getPathStack();
        const pathName = info[0].name;
        // 判断当前页面栈
        if (pathName == EntryRouter.UnlockPage) {
          // 认证成功，跳转到 VaultPage
          this.pathInfos.replacePath({ name: EntryRouter.VaultPage });
        } else {
          this.pathInfos.pop();
        }
      } else {
        IBestToast.show('主密码错误');
        return;
      }
    } catch (error) {
      Logger.error(`Master password verification failed: ${error}`);
      IBestToast.show('验证失败，请重试');
      return;
    }
  }

  // 发起生物识别认证
  startBiometricAuth() {
    try {
      const rand = cryptoFramework.createRandom();
      const len: number = 16; // Generate a 16-byte random number.
      let randData: Uint8Array | null = null;
      let retryCount = 0;
      while (retryCount < 3) {
        randData = rand?.generateRandomSync(len)?.data;
        if (randData) {
          break;
        }
        retryCount++;
      }
      if (!randData) {
        IBestToast.show('生物识别初始化失败');
        return;
      }

      // 设置认证参数
      const authParam: userAuth.AuthParam = {
        challenge: randData,
        authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
      };

      // 配置认证界面
      const widgetParam: userAuth.WidgetParam = {
        title: '请进行身份认证',
      };

      // 获取认证对象
      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      Logger.info('get userAuth instance success');

      // 订阅认证结果
      userAuthInstance.on('result', {
        onResult: (result) => {
          Logger.info(`userAuthInstance callback result: ${JSON.stringify(result)}`);
          // 取消订阅认证结果
          userAuthInstance.off('result');

          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
            const info: NavPathInfo[] = this.pathInfos.getPathStack();
            const pathName = info[0].name;
            // 判断当前页面栈
            if (pathName == EntryRouter.UnlockPage) {
              // 认证成功，跳转到 VaultPage
              this.pathInfos.replacePath({ name: EntryRouter.VaultPage });
            } else {
              this.pathInfos.pop();
            }
          } else {
            // 认证失败，显示提示
            IBestToast.show('生物认证失败');
          }
        }
      });
      Logger.info('auth on success');
      userAuthInstance.start();
      Logger.info('auth start success');
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to start biometric auth. Error: ${JSON.stringify(err)}`);
      IBestToast.show('生物识别启动失败');
    }
  }
}