import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { display } from '@kit.ArkUI';
import { QrDecoder } from './QrDecoder';

export interface QrPreviewInfo {
  width: number;
  height: number;
  rotation: number;
  flash: boolean;
}

/** Owns all camera resources. Operations are serialized; stop invalidates pending callbacks immediately. */
export class QrCameraController {
  private generation: number = 0;
  private serial: Promise<void> = Promise.resolve();
  private input?: camera.CameraInput;
  private session?: camera.PhotoSession | camera.VideoSession;
  private preview?: camera.PreviewOutput;
  private frameOutput?: camera.PreviewOutput;
  private receiver?: image.ImageReceiver;
  private frameTask?: Promise<void>;
  private lastFrame: number = 0;
  private frameErrors: number = 0;
  private firstFrameTimer: number = -1;
  private rotationListening: boolean = false;
  private profile?: camera.Profile;
  private onPreview?: (info: QrPreviewInfo) => void;
  private readonly rotationChanged = (): void => this.updateRotation();

  start(context: common.UIAbilityContext, surface: string, onResult: (values: string[]) => void,
    onError: () => void, onPreview: (info: QrPreviewInfo) => void): Promise<void> {
    const token = ++this.generation;
    const operation = this.serial.then(async () => {
      await this.releaseResources();
      if (token !== this.generation) { return; }
      try {
        const manager = camera.getCameraManager(context);
        const devices = manager.getSupportedCameras();
        if (devices.length === 0) { throw new Error('qr_no_camera'); }
        const device = devices.find((item: camera.CameraDevice) =>
          item.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK) ?? devices[0];
        const modes = manager.getSupportedSceneModes(device);
        const mode = modes.includes(camera.SceneMode.NORMAL_PHOTO) ? camera.SceneMode.NORMAL_PHOTO :
          camera.SceneMode.NORMAL_VIDEO;
        const capabilities = manager.getSupportedOutputCapability(device, mode);
        const profiles = capabilities.previewProfiles.filter((item: camera.Profile) =>
          item.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP && item.size.width > 0 &&
          item.size.height > 0 && item.size.width <= 1920 && item.size.height <= 1920);
        profiles.sort((a: camera.Profile, b: camera.Profile) =>
          Math.abs(1280 * 720 - a.size.width * a.size.height) -
          Math.abs(1280 * 720 - b.size.width * b.size.height));
        if (profiles.length === 0) { throw new Error('qr_camera_format'); }
        // Retry other supported sizes if the device cannot configure this dual-preview combination.
        for (let index = 0; index < profiles.length; index++) {
          try {
            const profile = profiles[index];
            this.profile = profile;
            this.onPreview = onPreview;
            this.receiver = image.createImageReceiver(profile.size, image.ImageFormat.JPEG, 3);
            const receiver = this.receiver;
            const frameSurface = await receiver.getReceivingSurfaceId();
            this.check(token);
            this.preview = manager.createPreviewOutput(profile, surface);
            this.frameOutput = manager.createPreviewOutput(profile, frameSurface);
            this.input = manager.createCameraInput(device);
            this.input.on('error', device, () => this.fail(token, onError));
            await this.input.open();
            this.check(token);
            this.session = manager.createSession(mode) as camera.PhotoSession | camera.VideoSession;
            const session = this.session;
            if (mode === camera.SceneMode.NORMAL_PHOTO) {
              (session as camera.PhotoSession).on('error', () => this.fail(token, onError));
            } else {
              (session as camera.VideoSession).on('error', () => this.fail(token, onError));
            }
            session.beginConfig();
            session.addInput(this.input);
            session.addOutput(this.preview);
            session.addOutput(this.frameOutput);
            await session.commitConfig();
            this.check(token);
            try {
              if (session.isFocusModeSupported(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO)) {
                session.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
              }
            } catch (_) {}
            this.updateRotation();
            display.on('change', this.rotationChanged);
            this.rotationListening = true;
            this.frameErrors = 0;
            this.lastFrame = 0;
            receiver.on('imageArrival', () => {
              if (token !== this.generation || this.frameTask) { return; }
              // Drain even skipped frames: otherwise the Surface queue can fill and stall the camera.
              const decodeFrame = Date.now() - this.lastFrame >= 220;
              if (decodeFrame) { this.lastFrame = Date.now(); }
              this.frameTask = this.readFrame(receiver, token, onResult, onError, decodeFrame).finally(() => {
                this.frameTask = undefined;
              });
            });
            await session.start();
            this.check(token);
            this.firstFrameTimer = setTimeout(() => this.fail(token, onError), 8000);
            return;
          } catch (error) {
            await this.releaseResources();
            this.check(token);
            if (index === profiles.length - 1) { throw new Error('qr_camera_configuration'); }
          }
        }
      } catch (_) {
        const current = token === this.generation;
        await this.releaseResources();
        if (current && token === this.generation) { onError(); }
      }
    });
    this.serial = operation.catch(() => {});
    return this.serial;
  }

  stop(): Promise<void> {
    ++this.generation;
    const operation = this.serial.then(() => this.releaseResources());
    this.serial = operation.catch(() => {});
    return this.serial;
  }

  setFlash(enabled: boolean): boolean {
    try {
      const mode = enabled ? camera.FlashMode.FLASH_MODE_ALWAYS_OPEN : camera.FlashMode.FLASH_MODE_CLOSE;
      if (!this.session?.isFlashModeSupported(mode)) { return false; }
      this.session.setFlashMode(mode);
      return true;
    } catch (_) { return false; }
  }

  private check(token: number): void {
    if (token !== this.generation) { throw new Error('qr_camera_cancelled'); }
  }

  private fail(token: number, onError: () => void): void {
    if (token !== this.generation) { return; }
    void this.stop();
    onError();
  }

  private updateRotation(): void {
    try {
      if (!this.preview || !this.profile || !this.session) { return; }
      const rotation = this.preview.getPreviewRotation(display.getDefaultDisplaySync().rotation * 90);
      this.preview.setPreviewRotation(rotation, false);
      this.onPreview?.({ width: this.profile.size.width, height: this.profile.size.height,
        rotation: rotation, flash: this.session.isFlashModeSupported(camera.FlashMode.FLASH_MODE_ALWAYS_OPEN) });
    } catch (_) {
      // Devices that cannot rotate the preview still decode full frames, in any QR orientation.
      if (this.profile) {
        this.onPreview?.({ width: this.profile.size.width, height: this.profile.size.height,
          rotation: 0, flash: false });
      }
    }
  }

  private async readFrame(receiver: image.ImageReceiver, token: number, onResult: (values: string[]) => void,
    onError: () => void, decodeFrame: boolean): Promise<void> {
    let frame: image.Image | undefined;
    try {
      frame = await receiver.readLatestImage();
      if (!frame || token !== this.generation || !decodeFrame) { return; }
      let component: image.Component;
      let rawYuv = false;
      try {
        component = await frame.getComponent(image.ComponentType.YUV_Y);
        if (component.rowStride <= 0 || component.pixelStride <= 0) { throw new Error('qr_plane_stride'); }
      } catch (_) {
        // Public ImageReceiver routes camera YUV through its JPEG channel on some OH versions.
        // The producer is explicitly YUV_420_SP; this is not interpreted as an encoded JPEG.
        component = await frame.getComponent(image.ComponentType.JPEG);
        rawYuv = true;
      }
      this.check(token);
      const width = frame.size.width;
      const height = frame.size.height;
      const stride = component.rowStride > 0 ? component.rowStride : (rawYuv ? width : 0);
      const pixelStride = rawYuv ? 1 : component.pixelStride;
      const values = await QrDecoder.gray(new Uint8Array(component.byteBuffer), width, height, stride, pixelStride);
      this.frameErrors = 0;
      clearTimeout(this.firstFrameTimer);
      this.firstFrameTimer = -1;
      if (token === this.generation && values.length > 0) { onResult(values); }
    } catch (_) {
      if (token === this.generation && ++this.frameErrors >= 3) { this.fail(token, onError); }
    } finally {
      try { await frame?.release(); } catch (_) {}
    }
  }

  private async releaseResources(): Promise<void> {
    clearTimeout(this.firstFrameTimer);
    this.firstFrameTimer = -1;
    if (this.rotationListening) {
      try { display.off('change', this.rotationChanged); } catch (_) {}
      this.rotationListening = false;
    }
    try { this.receiver?.off('imageArrival'); } catch (_) {}
    try { await this.session?.stop(); } catch (_) {}
    await this.frameTask;
    try { await this.session?.release(); } catch (_) {}
    try { await this.preview?.release(); } catch (_) {}
    try { await this.frameOutput?.release(); } catch (_) {}
    try { await this.input?.close(); } catch (_) {}
    try { await this.receiver?.release(); } catch (_) {}
    this.session = undefined;
    this.preview = undefined;
    this.frameOutput = undefined;
    this.input = undefined;
    this.receiver = undefined;
    this.profile = undefined;
    this.onPreview = undefined;
  }
}
