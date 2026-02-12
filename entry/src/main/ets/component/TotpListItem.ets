import { IBestToast } from '@ibestservices/ibest-ui';
import { Cipher } from '../model/CipherModels';
import { TOTPUtil } from '../utils/TOTPUtil';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';

/**
 * TOTP验证码列表项组件
 * 显示密码项信息和TOTP验证码
 */
@Component
export struct TotpListItem {
  @Prop cipher: Cipher;
  @State currentCode: string = '--- ---';
  @State remainingSeconds: number = 30;
  @Prop currentTime: number = Date.now(); // 从父组件接收时间变化
  private timerId: number = -1;
  onTap?: () => void;

  async aboutToAppear() {
    await this.updateCode();
    this.startTimer();
  }

  aboutToDisappear() {
    this.stopTimer();
  }

  /**
   * 更新验证码和剩余时间
   */
  private async updateCode() {
    if (this.cipher.login?.totp) {
      try {
        const code = await TOTPUtil.generateTOTP(this.cipher.login.totp);
        // 格式化为 3+3 格式，便于阅读
        this.currentCode = `${code.substring(0, 3)} ${code.substring(3)}`;
        this.remainingSeconds = TOTPUtil.getRemainingSeconds();
      } catch (error) {
        this.currentCode = '------';
      }
    }
  }

  /**
   * 启动定时器
   */
  private startTimer() {
    // 每秒更新一次
    this.timerId = setInterval(() => {
      const newRemaining = TOTPUtil.getRemainingSeconds();

      // 检测是否进入新的30秒周期
      if (newRemaining > this.remainingSeconds || newRemaining === 30) {
        // 新的周期，更新验证码
        this.updateCode();
      } else {
        // 仅更新剩余时间
        this.remainingSeconds = newRemaining;
      }
    }, 1000);
  }

  /**
   * 停止定时器
   */
  private stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 复制验证码到剪贴板
   */
  private async copyCode() {
    try {
      // 移除空格后复制
      const codeToCopy = this.currentCode.replace(/\s/g, '');
      if (codeToCopy === '------') {
        IBestToast.show('无效的验证码');
        return;
      }

      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, codeToCopy);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      IBestToast.show('已复制');
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to copy code: ${err.message}`);
      IBestToast.show('复制失败');
    }
  }

  build() {
    Column() {
      // 第一行：名称和用户名
      Row() {
        Column() {
          Text(this.cipher.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.cipher.login?.username) {
            Text(this.cipher.login.username)
              .fontSize(14)
              .fontColor('#666666')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 12 })
      .onClick(() => {
        this.onTap?.();
      })

      // 第二行：验证码和倒计时
      Row() {
        // 验证码
        Text(this.currentCode)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .onClick(() => this.copyCode())

        Blank()

        // 状态指示器和剩余时间
        Row() {
          Circle()
            .width(8)
            .height(8)
            .fill(this.remainingSeconds > 5 ? Color.Green : Color.Red)

          Text(`${this.remainingSeconds}s`)
            .fontSize(14)
            .fontColor('#666666')
            .margin({ left: 4, right: 8 })

          // 复制按钮
          Button() {
            Image($r('app.media.icon_copy'))
              .width(18)
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => this.copyCode())
          .margin({ right: 8 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .margin({ bottom: 8 })
  }
}
