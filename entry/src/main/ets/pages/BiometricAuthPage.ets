import { EntryRouter } from '../../../../EntryRouter';
import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { PromptAction } from '@kit.ArkUI';
import { DataPreferences } from '@abner/datastore';
import { BACKGROUND_TIMESTAMP } from '../utils/Constants';

@Builder
export function BiometricAuthPageBuilder() {
  BiometricAuthPage();
}

@Component
export struct BiometricAuthPage {
  pathInfos: NavPathStack = new NavPathStack();
  private exitTime: number = 0;

  aboutToAppear() {
    // 页面加载后自动拉起生物认证
    this.startBiometricAuth();
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

        // 解锁按钮
        Button() {
          Text('解锁')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .width(200)
        .height(50)
        .backgroundColor('#007DFF')
        .borderRadius(25)
        .onClick(() => {
          // 点击解锁按钮拉起生物认证
          this.startBiometricAuth();
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
        let promptAction: PromptAction = this.getUIContext().getPromptAction();
        this.exitTime = currentTime;
        promptAction.showToast({
          message: '再按一次退出',
          duration: 2000
        })
      }
      return true;
    })
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
        this.getUIContext().getPromptAction().showToast({
          message: '生物识别初始化失败'
        });
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
      console.info('get userAuth instance success');

      // 订阅认证结果
      userAuthInstance.on('result', {
        onResult: (result) => {
          console.info(`userAuthInstance callback result: ${JSON.stringify(result)}`);
          // 取消订阅认证结果
          userAuthInstance.off('result');

          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            DataPreferences.getInstance().putSync(BACKGROUND_TIMESTAMP, Math.floor(Date.now() / 1000));
            const info: NavPathInfo[] = this.pathInfos.getPathStack();
            const pathName = info[0].name;
            if (pathName == EntryRouter.BiometricAuthPage) {
              // 认证成功，跳转到 VaultPage
              this.pathInfos.replacePath({ name: EntryRouter.VaultPage });
            } else {
              this.pathInfos.pop();
            }
          } else {
            // 认证失败，显示提示
            this.getUIContext().getPromptAction().showToast({
              message: '认证失败'
            });
          }
        }
      });
      console.info('auth on success');
      userAuthInstance.start();
      console.info('auth start success');
    } catch (error) {
      const err = error as BusinessError;
      console.error(`Failed to start biometric auth. Error: ${JSON.stringify(err)}`);
      this.getUIContext().getPromptAction().showToast({
        message: '生物识别启动失败'
      });
    }
  }
}