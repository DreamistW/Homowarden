import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { IBestToast } from '@ibestservices/ibest-ui';
import { Logger } from '@nzy/logger';
import { TOTPUtil } from '../utils/TOTPUtil';
import { AdaptiveIconButton } from './AdaptiveButton';

/**
 * TOTP验证码显示组件
 * 显示6位验证码和剩余时间，支持复制
 */
@Component
export struct TotpDisplayItem {
  @Prop secret: string;
  @State currentCode: string = '--- ---';
  @State remainingSeconds: number = 30;
  private timerId: number = -1;

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
    try {
      const code = await TOTPUtil.generateTOTP(this.secret);
      // 格式化为 3+3 格式，便于阅读
      this.currentCode = `${code.substring(0, 3)} ${code.substring(3)}`;
      this.remainingSeconds = TOTPUtil.getRemainingSeconds();
    } catch (error) {
      Logger.error(`Failed to update code: ${JSON.stringify(error)}`);
      this.currentCode = '------';
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
        IBestToast.show($r('app.string.totp_invalid'));
        return;
      }

      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, codeToCopy);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      IBestToast.show($r('app.string.totp_copied'));
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to copy code: ${err.message}`);
      IBestToast.show($r('app.string.totp_copy_failed'));
    }
  }

  build() {
    Row() {
      // 标签
      Text($r('app.string.totp_title'))
        .fontSize(14)
        .fontColor('#666666')
        .width(80)

      // 验证码显示
      Text(this.currentCode)
        .fontSize(14)
        .layoutWeight(1)

      // 状态指示器
      Circle()
        .width(8)
        .height(8)
        .fill(this.remainingSeconds > 5 ? Color.Green : Color.Red)
        .margin({ right: 4 })

      // 剩余时间
      Text($r('app.string.totp_seconds', this.remainingSeconds))
        .fontSize(12)
        .fontColor('#666666')
        .width(42)

      // 复制按钮
      AdaptiveIconButton({
        icon: $r('app.media.icon_copy'),
        accessibilityLabel: $r('app.string.accessibility_copy_totp'),
        barWidth: 40,
        barHeight: 40,
        iconWidth: 20,
        iconHeight: 20,
        contentPadding: 6,
        barBottomMargin: 0,
        onButtonClick: () => {
          this.copyCode();
        }
      })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
