import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { relationalStore } from '@kit.ArkData';
import { Logger } from '@nzy/logger';
import { AdaptiveIconButton } from './AdaptiveButton';
import { AppDropdown } from './AppDropdown';
import { AppDropdownOption } from '../model/AppUiModels';
import { AppToast } from '../utils/AppToast';
import { EMAIL_KEY } from '../utils/Constants';
import { queryAssetSync } from '../utils/AssetUtil';
import { GeneratorDatabaseUtil, GENERATOR_HISTORY_TABLE } from '../utils/GeneratorDatabaseUtil';
import { GeneratorRecordType } from '../model/GeneratorHistoryModel';
import { PasswordGenerator } from '../utils/PasswordGenerator';
import { UsernameGenerator, UsernameType } from '../utils/UsernameGenerator';

/** 面板支持的生成模式：固定由调用方按字段指定 */
export enum GeneratorPanelMode {
  PASSWORD = 0,
  USERNAME = 1
}

const PASSWORD_LENGTH_MIN: number = 4;
const PASSWORD_LENGTH_MAX: number = 32;
const PASSWORD_LENGTH_DEFAULT: number = 16;
const MIN_COUNT_MIN: number = 0;

/**
 * 生成器面板：在添加密码项页面以底部面板形式复用生成能力，固定单一模式，
 * 成功生成后写入历史，点击"使用"通过 onUse 回填到目标输入框
 */
@Component
export struct GeneratorPanel {
  mode: GeneratorPanelMode = GeneratorPanelMode.PASSWORD;
  onUse: (value: string) => void = () => {};

  // 密码模式选项
  @State length: number = PASSWORD_LENGTH_DEFAULT;
  @State upperOn: boolean = true;
  @State lowerOn: boolean = true;
  @State digitOn: boolean = true;
  @State symbolOn: boolean = true;
  @State minDigits: number = 1;
  @State minSymbols: number = 1;
  private lengthChangePending: boolean = false;

  // 用户名模式选项（默认随机单词，避免无邮箱时生成空值）
  @State usernameType: UsernameType = UsernameType.RANDOM_WORD;
  @State email: string = '';
  @State capitalize: boolean = true;
  @State includeNumber: boolean = true;

  @State output: string = '';
  private dbUtil: GeneratorDatabaseUtil = GeneratorDatabaseUtil.getInstance();
  private generationQueue: Promise<void> = Promise.resolve();
  private generationRequestId: number = 0;
  private usernameTypeOptions: AppDropdownOption[] = [
    AppDropdownOption.create($r('app.string.username_type_word'), UsernameType.RANDOM_WORD),
    AppDropdownOption.create($r('app.string.username_type_email'), UsernameType.EMAIL_ALIAS)
  ];

  async aboutToAppear(): Promise<void> {
    this.email = queryAssetSync(EMAIL_KEY);
    await this.regenerate();
  }

  /** 依据当前模式重新生成 */
  async regenerate(): Promise<void> {
    const requestId: number = ++this.generationRequestId;
    const task: Promise<void> = this.generationQueue.then(async () => {
      if (requestId !== this.generationRequestId) {
        return;
      }
      if (this.mode === GeneratorPanelMode.PASSWORD) {
        await this.regeneratePassword(requestId);
      } else {
        await this.regenerateUsername(requestId);
      }
    });
    this.generationQueue = task.catch(() => {});
    await task;
  }

  // 依据当前密码选项生成密码，成功后写入历史记录
  private async regeneratePassword(requestId: number): Promise<void> {
    try {
      const value: string = await PasswordGenerator.generate({
        length: this.length,
        upperOn: this.upperOn,
        lowerOn: this.lowerOn,
        digitOn: this.digitOn,
        symbolOn: this.symbolOn,
        minDigits: this.minDigits,
        minSymbols: this.minSymbols
      });
      if (requestId !== this.generationRequestId) {
        return;
      }
      this.output = value;
      if (value.length > 0) {
        await this.saveToHistory(value, GeneratorRecordType.PASSWORD);
      }
    } catch (err) {
      const error = err as Error;
      Logger.error(`Failed to generate password: ${error.message}`);
      AppToast.show(this.getUIContext(), error.message.length > 0 ?
        error.message : $r('app.string.error_unknown'));
    }
  }

  // 依据当前用户名选项生成用户名，成功后写入历史记录
  private async regenerateUsername(requestId: number): Promise<void> {
    if (this.usernameType === UsernameType.EMAIL_ALIAS) {
      // 邮箱为空时不生成，避免产生无效别名
      if (this.email.trim().length === 0) {
        this.output = '';
        return;
      }
    }
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined || hostContext === null) {
      return;
    }
    try {
      const value: string = await UsernameGenerator.generate({
        type: this.usernameType,
        email: this.email,
        capitalize: this.capitalize,
        includeNumber: this.includeNumber
      }, hostContext as Context);
      if (requestId !== this.generationRequestId) {
        return;
      }
      this.output = value;
      if (value.length > 0) {
        await this.saveToHistory(value, GeneratorRecordType.USERNAME);
      }
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(`Failed to generate username: ${error.message}`);
    }
  }

  // 将生成结果写入历史记录表
  private async saveToHistory(content: string, type: GeneratorRecordType): Promise<void> {
    const item: relationalStore.ValuesBucket = {
      id: this.dbUtil.generateId(),
      content: content,
      type: type,
      timestamp: Date.now()
    };
    await this.dbUtil.insertData(GENERATOR_HISTORY_TABLE, item);
  }

  // 调整数字最小个数并重新生成
  private async adjustMinDigits(delta: number): Promise<void> {
    const max: number = this.length - this.minSymbols;
    let next: number = this.minDigits + delta;
    if (next < MIN_COUNT_MIN) {
      next = MIN_COUNT_MIN;
    }
    if (next > max) {
      next = max;
    }
    if (next !== this.minDigits) {
      this.minDigits = next;
      await this.regenerate();
    }
  }

  // 调整符号最小个数并重新生成
  private async adjustMinSymbols(delta: number): Promise<void> {
    const max: number = this.length - this.minDigits;
    let next: number = this.minSymbols + delta;
    if (next < MIN_COUNT_MIN) {
      next = MIN_COUNT_MIN;
    }
    if (next > max) {
      next = max;
    }
    if (next !== this.minSymbols) {
      this.minSymbols = next;
      await this.regenerate();
    }
  }

  /** 更新密码长度，并同步归一化数字与符号的最小个数 */
  private updatePasswordLength(value: number): void {
    const nextLength: number = Math.min(PASSWORD_LENGTH_MAX,
      Math.max(PASSWORD_LENGTH_MIN, Math.round(value)));
    if (nextLength !== this.length) {
      this.lengthChangePending = true;
    }

    let nextMinDigits: number = Math.max(MIN_COUNT_MIN, Math.floor(this.minDigits));
    let nextMinSymbols: number = Math.max(MIN_COUNT_MIN, Math.floor(this.minSymbols));
    while (nextMinDigits + nextMinSymbols > nextLength) {
      if (nextMinDigits > nextMinSymbols) {
        nextMinDigits--;
      } else {
        nextMinSymbols--;
      }
    }

    this.length = nextLength;
    this.minDigits = nextMinDigits;
    this.minSymbols = nextMinSymbols;
  }

  build() {
    Column() {
      // 模式标题（关闭按钮复用半模态面板自带的，避免重复）
      Text(this.mode === GeneratorPanelMode.PASSWORD ?
        $r('app.string.generator_tab_password') : $r('app.string.generator_tab_username'))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ top: 4, bottom: 16 })

      // 输出行：生成值 + 重新生成
      Row() {
        Text(this.output.length > 0 ? this.output : $r('app.string.generator_empty'))
          .layoutWeight(1)
          .fontSize(18)
          .fontFamily('monospace')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        AdaptiveIconButton({
          icon: $r('app.media.icon_restore'),
          accessibilityLabel: $r('app.string.accessibility_generate'),
          barWidth: 40,
          barHeight: 40,
          iconWidth: 20,
          iconHeight: 20,
          contentPadding: 6,
          barBottomMargin: 0,
          onButtonClick: async () => {
            await this.regenerate();
          }
        })
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.start_window_background'))

      // 选项区
      Scroll() {
        if (this.mode === GeneratorPanelMode.PASSWORD) {
          this.PasswordControls()
        } else {
          this.UsernameControls()
        }
      }
      .scrollBar(BarState.Auto)
      .scrollable(ScrollDirection.Vertical)
      .align(Alignment.TopStart)
      .width('100%')
      .layoutWeight(1)
      .margin({ top: 12 })

      // 使用按钮：回填到目标输入框并关闭面板
      Button($r('app.string.cipher_use_generated'))
        .type(ButtonType.Capsule)
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.button_background_color'))
        .fontColor($r('app.color.button_foreground_color'))
        .enabled(this.output.length > 0)
        .opacity(this.output.length > 0 ? 1 : 0.4)
        .margin({ top: 12 })
        .onClick(() => {
          if (this.output.length > 0) {
            this.onUse(this.output);
          }
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 28, bottom: 16 })
  }

  @Builder
  PasswordControls() {
    Column({ space: 16 }) {
      // 长度进度条
      Column({ space: 8 }) {
        Row() {
          Text($r('app.string.password_length'))
            .fontSize(14)
            .fontColor('#666666')
          Blank()
          Text(`${this.length}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')

        Slider({
          value: this.length,
          min: PASSWORD_LENGTH_MIN,
          max: PASSWORD_LENGTH_MAX,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .blockColor($r('app.color.button_background_color'))
          .selectedColor($r('app.color.button_background_color'))
          .trackColor('#E0E0E0')
          .accessibilityText($r('app.string.accessibility_password_length'))
          .onChange(async (value: number, mode: SliderChangeMode) => {
            this.updatePasswordLength(value);
            if (this.lengthChangePending &&
              (mode === SliderChangeMode.End || mode === SliderChangeMode.Click)) {
              this.lengthChangePending = false;
              await this.regenerate();
            }
          })
      }
      .width('100%')

      Row() {
        Text($r('app.string.password_uppercase'))
          .fontSize(16)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.upperOn })
          .accessibilityText($r('app.string.password_uppercase'))
          .onChange(async (on: boolean) => {
            this.upperOn = on;
            await this.regenerate();
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      Row() {
        Text($r('app.string.password_lowercase'))
          .fontSize(16)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.lowerOn })
          .accessibilityText($r('app.string.password_lowercase'))
          .onChange(async (on: boolean) => {
            this.lowerOn = on;
            await this.regenerate();
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      Row() {
        Text($r('app.string.password_digits'))
          .fontSize(16)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.digitOn })
          .accessibilityText($r('app.string.password_digits'))
          .onChange(async (on: boolean) => {
            this.digitOn = on;
            await this.regenerate();
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      Row() {
        Text($r('app.string.password_symbols'))
          .fontSize(16)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.symbolOn })
          .accessibilityText($r('app.string.password_symbols'))
          .onChange(async (on: boolean) => {
            this.symbolOn = on;
            await this.regenerate();
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      // 数字最小个数步进
      Row() {
        Text($r('app.string.password_min_digits'))
          .fontSize(16)
          .layoutWeight(1)
        Row({ space: 8 }) {
          AdaptiveIconButton({
            icon: $r('app.media.icon_minus'),
            accessibilityLabel: $r('app.string.accessibility_decrease_min_digits'),
            barWidth: 36,
            barHeight: 36,
            iconWidth: 16,
            iconHeight: 16,
            contentPadding: 4,
            barBottomMargin: 0,
            onButtonClick: async () => {
              if (this.digitOn) {
                await this.adjustMinDigits(-1);
              }
            }
          })
          Text(`${this.minDigits}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .width(40)
            .opacity(this.digitOn ? 1 : 0.4)
          AdaptiveIconButton({
            icon: $r('app.media.icon_add'),
            accessibilityLabel: $r('app.string.accessibility_increase_min_digits'),
            barWidth: 36,
            barHeight: 36,
            iconWidth: 16,
            iconHeight: 16,
            contentPadding: 4,
            barBottomMargin: 0,
            onButtonClick: async () => {
              if (this.digitOn) {
                await this.adjustMinDigits(1);
              }
            }
          })
        }
        .opacity(this.digitOn ? 1 : 0.4)
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      // 符号最小个数步进
      Row() {
        Text($r('app.string.password_min_symbols'))
          .fontSize(16)
          .layoutWeight(1)
        Row({ space: 8 }) {
          AdaptiveIconButton({
            icon: $r('app.media.icon_minus'),
            accessibilityLabel: $r('app.string.accessibility_decrease_min_symbols'),
            barWidth: 36,
            barHeight: 36,
            iconWidth: 16,
            iconHeight: 16,
            contentPadding: 4,
            barBottomMargin: 0,
            onButtonClick: async () => {
              if (this.symbolOn) {
                await this.adjustMinSymbols(-1);
              }
            }
          })
          Text(`${this.minSymbols}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .width(40)
            .opacity(this.symbolOn ? 1 : 0.4)
          AdaptiveIconButton({
            icon: $r('app.media.icon_add'),
            accessibilityLabel: $r('app.string.accessibility_increase_min_symbols'),
            barWidth: 36,
            barHeight: 36,
            iconWidth: 16,
            iconHeight: 16,
            contentPadding: 4,
            barBottomMargin: 0,
            onButtonClick: async () => {
              if (this.symbolOn) {
                await this.adjustMinSymbols(1);
              }
            }
          })
        }
        .opacity(this.symbolOn ? 1 : 0.4)
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
    }
    .width('100%')
    .padding({ left: 8, right: 20, top: 8, bottom: 8 })
  }

  @Builder
  UsernameControls() {
    Column({ space: 16 }) {
      // 类型下拉
      Column({ space: 8 }) {
        Text($r('app.string.username_type'))
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
        AppDropdown({
          options: this.usernameTypeOptions,
          value: this.usernameType,
          accessibilityLabel: $r('app.string.username_type'),
          onChange: async (value: number) => {
            this.usernameType = value as UsernameType;
            await this.regenerate();
          }
        })
      }
      .width('100%')

      if (this.usernameType === UsernameType.EMAIL_ALIAS) {
        Column({ space: 8 }) {
          Text($r('app.string.username_email'))
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
          TextInput({ text: this.email, placeholder: $r('app.string.username_email_placeholder') })
            .accessibilityText($r('app.string.username_email'))
            .type(InputType.Email)
            .fontSize(16)
            .height(48)
            .onChange((v: string) => {
              this.email = v;
            })
            .onSubmit(async () => {
              await this.regenerate();
            })
        }
        .width('100%')
      } else {
        Row() {
          Text($r('app.string.username_capitalize'))
            .fontSize(16)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.capitalize })
            .accessibilityText($r('app.string.username_capitalize'))
            .onChange(async (on: boolean) => {
              this.capitalize = on;
              await this.regenerate();
            })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })

        Row() {
          Text($r('app.string.username_include_number'))
            .fontSize(16)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.includeNumber })
            .accessibilityText($r('app.string.username_include_number'))
            .onChange(async (on: boolean) => {
              this.includeNumber = on;
              await this.regenerate();
            })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding({ left: 8, right: 20, top: 8, bottom: 8 })
  }
}
