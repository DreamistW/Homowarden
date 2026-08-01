/** 应用弹窗支持的关闭动作。 */
export enum AppDialogAction {
  CANCEL,
  CONFIRM
}

/** 提供异步关闭校验和重复提交保护的通用模态弹窗。 */
@Component
export struct AppDialog {
  @Link visible: boolean;
  title: ResourceStr = '';
  showCancelButton: boolean = true;
  closeOnClickOverlay: boolean = false;
  @BuilderParam defaultBuilder: () => void;
  beforeClose: (action: AppDialogAction) => Promise<boolean> = async () => true;
  @State submitting: boolean = false;

  private async close(action: AppDialogAction): Promise<void> {
    // 异步校验完成前禁止再次关闭，避免确认操作被并发执行。
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      const canClose = await this.beforeClose(action);
      if (canClose) {
        this.visible = false;
      }
    } catch (error) {
      // 关闭钩子异常时保留弹窗，由调用方继续展示原有输入和错误状态。
      return;
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private modalContent() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          if (this.closeOnClickOverlay) {
            void this.close(AppDialogAction.CANCEL);
          }
        })
      Column({ space: 16 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
        this.defaultBuilder()
        Row({ space: 12 }) {
          if (this.showCancelButton) {
            Button($r('app.string.common_cancel'))
              .enabled(!this.submitting)
              .onClick(() => {
                void this.close(AppDialogAction.CANCEL);
              })
          }
          Button($r('app.string.common_confirm'))
            .enabled(!this.submitting)
            .onClick(() => {
              void this.close(AppDialogAction.CONFIRM);
            })
        }
        .justifyContent(FlexAlign.End)
        .width('100%')
      }
      .padding(24)
      .width('86%')
      .backgroundColor($r('app.color.start_window_background'))
      .borderRadius(20)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column()
      .width(0)
      .height(0)
      .bindContentCover($$this.visible, this.modalContent(), {
        modalTransition: ModalTransition.NONE,
        onWillDismiss: (action: DismissContentCoverAction) => {
          // 系统侧滑等 dismiss 动作也必须经过统一的取消校验。
          if (this.showCancelButton) {
            void this.close(AppDialogAction.CANCEL);
          }
        }
      })
  }
}
