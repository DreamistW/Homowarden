import { common } from '@kit.AbilityKit';
import { AppDropdown } from './AppDropdown';
import { AppDropdownOption } from '../model/AppUiModels';
import { AppText, AppTextKey } from '../localization/AppText';
import { AppTextResolver } from '../localization/AppTextResolver';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { VaultImportPreview, VaultTransferFormat } from '../utils/VaultTransferCodec';
import { VaultTransferService } from '../utils/VaultTransferService';

@CustomDialog
export struct VaultTransferDialog {
  controller: CustomDialogController;
  importing: boolean = true;
  @State private format: VaultTransferFormat = VaultTransferFormat.JSON;
  @State private busy: boolean = false;
  @State private password: string = '';
  @State private errorText: ResourceStr = '';
  @State private resultText: ResourceStr = '';
  @State private previewCount: number = 0;
  @State private skippedCount: number = 0;
  @State private hasPreview: boolean = false;
  private preview: VaultImportPreview | null = null;
  private service: VaultTransferService = new VaultTransferService();
  private sessionTimer: number = -1;

  aboutToAppear(): void {
    this.service = new VaultTransferService();
    this.password = '';
    this.errorText = '';
    this.resultText = '';
    this.clearPreview();
    this.sessionTimer = setInterval(() => {
      if (!this.service.isCurrentSession()) {
        this.password = '';
        this.clearPreview();
        this.controller.close();
      }
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.sessionTimer !== -1) {
      clearInterval(this.sessionTimer);
      this.sessionTimer = -1;
    }
    this.password = '';
    this.clearPreview();
  }

  private clearPreview(): void {
    if (this.preview) {
      this.preview.items.length = 0;
    }
    this.preview = null;
    this.previewCount = 0;
    this.skippedCount = 0;
    this.hasPreview = false;
  }

  private async submit(): Promise<void> {
    if (this.busy || !this.service.isCurrentSession()) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (this.importing) {
        if (!this.hasPreview) {
          const preview = await this.service.selectImport(context, this.format);
          if (preview && this.service.isCurrentSession()) {
            if (preview.items.length === 0) {
              this.errorText = $r('app.string.transfer_no_items');
              return;
            }
            this.preview = preview;
            this.previewCount = preview.items.length;
            this.skippedCount = preview.skipped;
            this.hasPreview = true;
          }
        } else if (this.preview) {
          const count = this.previewCount;
          const refreshed = await this.service.importItems(this.preview.items);
          this.clearPreview();
          this.resultText = refreshed ? $r('app.string.transfer_import_success', count) :
            $r('app.string.transfer_import_refresh_failed', count);
        }
      } else {
        const verifier = new VaultViewModel();
        if (!await verifier.verifyMasterPassword(this.password)) {
          this.errorText = AppTextResolver.resource(verifier.errorMessage ?? new AppText(AppTextKey.VERIFICATION_FAILED));
          return;
        }
        this.password = '';
        if (await this.service.exportFile(context, this.format)) {
          this.resultText = $r('app.string.transfer_export_success');
        }
      }
    } catch (error) {
      this.errorText = this.errorResource((error as Error).message);
    } finally {
      this.busy = false;
    }
  }

  private errorResource(message: string): Resource {
    switch (message) {
      case 'transfer_encrypted_file':
        return $r('app.string.transfer_encrypted_file');
      case 'transfer_invalid_file':
        return $r('app.string.transfer_invalid_file');
      case 'transfer_file_size':
        return $r('app.string.transfer_file_size');
      case 'transfer_session_expired':
        return $r('app.string.transfer_session_expired');
      default:
        return this.importing ? $r('app.string.transfer_import_failed') : $r('app.string.transfer_export_failed');
    }
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Text(this.importing ? $r('app.string.transfer_import_title') : $r('app.string.transfer_export_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
        if (this.resultText) {
          Text(this.resultText)
            .fontSize(16)
        } else {
          Text(this.importing ? $r('app.string.transfer_import_hint') : $r('app.string.transfer_export_hint'))
            .fontSize(14)
          AppDropdown({
            options: [AppDropdownOption.create('Bitwarden JSON', VaultTransferFormat.JSON),
              AppDropdownOption.create('Bitwarden CSV', VaultTransferFormat.CSV)],
            value: this.format,
            disabled: this.busy,
            accessibilityLabel: $r('app.string.transfer_format'),
            onChange: (value: number) => {
              this.format = value;
              this.clearPreview();
              this.errorText = '';
            }
          })
          if (this.format === VaultTransferFormat.CSV) {
            Text($r('app.string.transfer_csv_hint'))
              .fontSize(14)
          }
          if (this.importing && this.hasPreview) {
            Text($r('app.string.transfer_import_preview', this.previewCount, this.skippedCount))
              .fontSize(16)
          }
          if (!this.importing) {
            TextInput({ placeholder: $r('app.string.unlock_enter_master_password'), text: this.password })
              .id('vault_export_password')
              .accessibilityText($r('app.string.unlock_enter_master_password'))
              .type(InputType.Password)
              .enabled(!this.busy)
              .onChange((value: string) => { this.password = value; this.errorText = ''; })
          }
          if (this.errorText) {
            Text(this.errorText)
              .fontSize(14)
              .fontColor($r('sys.color.warning'))
          }
          if (this.busy) {
            LoadingProgress()
              .width(28)
              .height(28)
          }
        }
      }
      .padding({ left: 24, right: 24, top: 24, bottom: 16 })

      Divider()
      Row() {
        if (!this.resultText) {
          Button(this.importing ? (this.hasPreview ? $r('app.string.transfer_import_title') :
            $r('app.string.transfer_choose_file')) : $r('app.string.transfer_export_title'))
            .id('vault_transfer_confirm')
            .layoutWeight(1)
            .height(48)
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .enabled(!this.busy)
            .onClick(() => { void this.submit(); })
        }
        Button(this.resultText ? $r('app.string.common_confirm') : $r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(48)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(!this.busy)
          .onClick(() => { this.controller.close(); })
      }
    }
  }
}
