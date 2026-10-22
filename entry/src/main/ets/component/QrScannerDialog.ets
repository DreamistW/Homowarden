import { abilityAccessCtrl, ApplicationStateChangeCallback, common } from '@kit.AbilityKit';
import { QrCameraController, QrPreviewInfo } from '../utils/QrCameraController';
import { QrDecoder } from '../utils/QrDecoder';

/** Reusable offline QR scanner. A caller may filter results without exposing their content in the UI. */
@CustomDialog
export struct QrScannerDialog {
  controller: CustomDialogController;
  selectResult: (values: string[]) => string | undefined = (values: string[]) => values[0];
  onDecoded: (value: string) => void = () => {};
  @State private status: ResourceStr = $r('app.string.scanner_opening');
  @State private notice: ResourceStr = $r('app.string.scanner_tip');
  @State private opening: boolean = false;
  @State private running: boolean = false;
  @State private picking: boolean = false;
  @State private flashAvailable: boolean = false;
  @State private flashOn: boolean = false;
  @State private previewWidth: number = 300;
  @State private previewHeight: number = 300;
  private readonly surface: XComponentController = new XComponentController();
  private readonly camera: QrCameraController = new QrCameraController();
  private context?: common.UIAbilityContext;
  private alive: boolean = false;
  private foreground: boolean = true;
  private complete: boolean = false;
  private surfaceReady: boolean = false;
  private permissionGranted: boolean = false;
  private action: number = 0;
  private containerWidth: number = 300;
  private previewRatio: number = 1;
  private pendingImage?: string[];
  private readonly lifecycle: ApplicationStateChangeCallback = {
    onApplicationForeground: (): void => {
      this.foreground = true;
      if (this.pendingImage !== undefined) {
        const values = this.pendingImage;
        this.pendingImage = undefined;
        this.receiveImage(values);
      }
      void this.startCamera(false);
    },
    onApplicationBackground: (): void => {
      this.foreground = false;
      ++this.action;
      this.running = false;
      this.flashOn = false;
      void this.camera.stop();
    }
  };

  aboutToAppear(): void {
    this.alive = true;
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.context.getApplicationContext().on('applicationStateChange', this.lifecycle);
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.pendingImage = undefined;
    ++this.action;
    void this.camera.stop();
    try { this.context?.getApplicationContext().off('applicationStateChange', this.lifecycle); } catch (_) {}
  }

  private async startCamera(requestPermission: boolean): Promise<void> {
    if (!this.alive || this.complete || !this.foreground || !this.surfaceReady || this.picking ||
      this.opening || this.running || !this.context || (!requestPermission && !this.permissionGranted)) { return; }
    const token = ++this.action;
    this.opening = true;
    this.status = $r('app.string.scanner_opening');
    try {
      if (requestPermission) {
        const grant = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context,
          ['ohos.permission.CAMERA']);
        this.permissionGranted = grant.authResults.length > 0 && grant.authResults[0] === 0;
        if (this.alive && !this.permissionGranted) { this.status = $r('app.string.scanner_permission'); }
      }
      if (!this.alive || token !== this.action || this.picking || !this.foreground) { return; }
      if (!this.permissionGranted) {
        this.status = $r('app.string.scanner_permission');
        return;
      }
      await this.camera.start(this.context, this.surface.getXComponentSurfaceId(),
        (values: string[]) => {
          if (this.alive && this.foreground && token === this.action && !this.picking) {
            this.deliver(values);
          }
        },
        () => {
          if (!this.alive || token !== this.action) { return; }
          this.running = false;
          this.flashOn = false;
          this.flashAvailable = false;
          this.status = $r('app.string.scanner_camera_unavailable');
        },
        (info: QrPreviewInfo) => {
          if (!this.alive || token !== this.action) { return; }
          this.surface.setXComponentSurfaceRect({ surfaceWidth: info.width, surfaceHeight: info.height });
          this.previewRatio = info.rotation % 180 === 0 ? info.width / info.height : info.height / info.width;
          this.resizePreview();
          this.flashAvailable = info.flash;
          this.running = true;
          this.status = $r('app.string.scanner_ready');
        });
    } catch (_) {
      if (this.alive && token === this.action) {
        this.status = $r('app.string.scanner_camera_unavailable');
      }
    } finally {
      this.opening = false;
      if (token !== this.action && this.alive && this.foreground && this.permissionGranted && !this.picking) {
        void this.startCamera(false);
      }
    }
  }

  private resizePreview(): void {
    this.previewWidth = Math.min(this.containerWidth, 320 * this.previewRatio);
    this.previewHeight = this.previewWidth / this.previewRatio;
  }

  private deliver(values: string[]): void {
    if (this.complete) { return; }
    const value = this.selectResult(values);
    if (value === undefined) {
      this.notice = $r('app.string.scanner_no_match');
      return;
    }
    this.complete = true;
    ++this.action;
    void this.camera.stop();
    this.controller.close();
    this.onDecoded(value);
  }

  private async pickImage(): Promise<void> {
    if (this.picking || !this.context || this.complete) { return; }
    this.picking = true;
    ++this.action;
    this.running = false;
    this.flashOn = false;
    try {
      await this.camera.stop();
      if (!this.alive) { return; }
      const values = await QrDecoder.pickImage(this.context);
      if (!this.alive || this.complete) { return; }
      if (values !== undefined) {
        if (this.foreground) { this.receiveImage(values); }
        else { this.pendingImage = values; }
      }
    } catch (_) {
      if (this.alive) { this.notice = $r('app.string.scanner_image_failed'); }
    } finally {
      this.picking = false;
      if (this.alive && !this.complete) { void this.startCamera(false); }
    }
  }

  private receiveImage(values: string[]): void {
    if (values.length === 0) { this.notice = $r('app.string.scanner_no_qr'); }
    else { this.deliver(values); }
  }

  build() {
    Column({ space: 12 }) {
      Text($r('app.string.scanner_title')).fontSize(20).fontWeight(FontWeight.Medium)
      Stack({ alignContent: Alignment.Center }) {
        XComponent({ id: 'homowarden-qr-preview', type: XComponentType.SURFACE, controller: this.surface })
          .width(this.previewWidth)
          .height(this.previewHeight)
          .onLoad(() => {
            this.surfaceReady = true;
            void this.startCamera(true);
          })
          .onDestroy(() => {
            this.surfaceReady = false;
            ++this.action;
            void this.camera.stop();
          })
        // Guide only: full camera frames are decoded, including QR codes outside the guide.
        Rect().width(220).height(220).radius(12).fill(Color.Transparent).stroke(Color.White).strokeWidth(2)
          .hitTestBehavior(HitTestMode.None)
        if (!this.running) {
          Column({ space: 12 }) {
            if (this.opening) { LoadingProgress().width(36).height(36).color(Color.White) }
            Text(this.status).fontColor(Color.White).textAlign(TextAlign.Center).padding(16)
          }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#C0000000')
        }
      }
      .width('100%').height(320).backgroundColor(Color.Black).borderRadius(12).clip(true)
      .onAreaChange((_: Area, area: Area) => {
        this.containerWidth = Number(area.width);
        this.resizePreview();
      })
      Text(this.notice).fontSize(14).textAlign(TextAlign.Center)
      Row({ space: 8 }) {
        Button($r('app.string.scanner_album'))
          .layoutWeight(1).enabled(!this.picking).onClick(() => { void this.pickImage(); })
        if (this.flashAvailable && this.running) {
          Button(this.flashOn ? $r('app.string.scanner_flash_off') : $r('app.string.scanner_flash_on'))
            .layoutWeight(1).onClick(() => {
              if (this.camera.setFlash(!this.flashOn)) { this.flashOn = !this.flashOn; }
            })
        }
        if (!this.running) {
          Button($r('app.string.scanner_retry'))
            .layoutWeight(1).enabled(!this.opening && !this.picking)
            .onClick(() => { void this.startCamera(true); })
        }
      }.width('100%')
      Button($r('app.string.common_cancel')).buttonStyle(ButtonStyleMode.TEXTUAL)
        .onClick(() => {
          this.complete = true;
          ++this.action;
          void this.camera.stop();
          this.controller.close();
        })
    }
    .padding(20).width('100%').constraintSize({ maxWidth: 520 })
  }
}
