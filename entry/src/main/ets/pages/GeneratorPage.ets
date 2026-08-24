import { Context } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { relationalStore } from '@kit.ArkData';
import { Logger } from '@nzy/logger';
import { AdaptiveIconButton } from '../component/AdaptiveButton';
import { AppDropdown } from '../component/AppDropdown';
import { AppDropdownOption } from '../model/AppUiModels';
import { AppToast } from '../utils/AppToast';
import { EMAIL_KEY } from '../utils/Constants';
import { queryAssetSync } from '../utils/AssetUtil';
import { GeneratorDatabaseUtil, GENERATOR_HISTORY_TABLE } from '../utils/GeneratorDatabaseUtil';
import { GeneratorRecordType } from '../model/GeneratorHistoryModel';
import { PasswordGenerator } from '../utils/PasswordGenerator';
import { UsernameGenerator, UsernameType } from '../utils/UsernameGenerator';
import { SegmentButton, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI';

const PASSWORD_LENGTH_MIN: number = 4;
const PASSWORD_LENGTH_MAX: number = 32;
const PASSWORD_LENGTH_DEFAULT: number = 16;
const MIN_COUNT_MIN: number = 0;

/** 密码与用户名生成器页签内容组件 */
@Component
export struct GeneratorPage {
  @Prop bottomContentInset: number = 0;
  @State activeSubTabIndexes: number[] = [0];
  @State private subTabOptions: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: [
      { text: $r('app.string.generator_tab_password') },
      { text: $r('app.string.generator_tab_username') }
    ] as SegmentButtonItemTuple,
    multiply: false,
    buttonPadding: { top: 12, right: 8, bottom: 12, left: 8 }
  });

  // 密码模式状态
  @State length: number = PASSWORD_LENGTH_DEFAULT;
  @State upperOn: boolean = true;
  @State lowerOn: boolean = true;
  @State digitOn: boolean = true;
  @State symbolOn: boolean = true;
  @State minDigits: number = 1;
  @State minSymbols: number = 1;
  private lengthChangePending: boolean = false;

  // 用户名模式状态
  @State usernameType: UsernameType = UsernameType.EMAIL_ALIAS;
  @State email: string = '';
  @State capitalize: boolean = true;
  @State includeNumber: boolean = true;

  @State output: string = '';
  private dbUtil: GeneratorDatabaseUtil = GeneratorDatabaseUtil.getInstance();
  private generationQueue: Promise<void> = Promise.resolve();
  private generationRequestId: number = 0;
  private usernameTypeOptions: AppDropdownOption[] = [
    AppDropdownOption.create($r('app.string.username_type_email'), UsernameType.EMAIL_ALIAS),
    AppDropdownOption.create($r('app.string.username_type_word'), UsernameType.RANDOM_WORD)
  ];

  async aboutToAppear(): Promise<void> {
    this.email = queryAssetSync(EMAIL_KEY);
    await this.regenerate();
  }

  /** 依据当前子页签重新生成 */
  async regenerate(): Promise<void> {
    const requestId: number = ++this.generationRequestId;
    const task: Promise<void> = this.generationQueue.then(async () => {
      if (requestId !== this.generationRequestId) {
        return;
      }
      if (this.activeSubTabIndexes[0] === 0) {
        await this.regeneratePassword(requestId);
      } else {
        await this.regenerateUsername(requestId);
      }
    });
    // 保持队列可继续执行，当前调用仍等待原任务并接收其异常
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

  // 复制当前生成结果到系统剪贴板
  private async copyOutput(): Promise<void> {
    if (this.output.length === 0) {
      return;
    }
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.output);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      AppToast.show(this.getUIContext(), $r('app.string.generator_copied'));
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to copy generated value: ${err.message}`);
    }
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

  build() {
    Column() {
      // 输出行：生成值 + 生成 + 复制
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
        AdaptiveIconButton({
          icon: $r('app.media.icon_copy'),
          accessibilityLabel: $r('app.string.accessibility_copy_generated'),
          barWidth: 40,
          barHeight: 40,
          iconWidth: 20,
          iconHeight: 20,
          contentPadding: 6,
          barBottomMargin: 0,
          onButtonClick: async () => {
            await this.copyOutput();
          }
        })
      }
      .width('100%')
      .padding(16)
      .borderRadius(12)
      .backgroundColor($r('app.color.start_window_background'))

      // 分段切换：密码 / 用户名
      Column() {
        SegmentButton({
          options: this.subTabOptions,
          selectedIndexes: $activeSubTabIndexes,
          onItemClicked: async (index: number) => {
            this.activeSubTabIndexes = [index];
            await this.regenerate();
          },
          enableStateAnimation: true
        })
      }
      .width('100%')
      .padding({ left: 8, right: 16 })
      .margin({ top: 12, bottom: 12 })

      // 单一滚动容器承载当前模式的选项，短内容也顶对齐，避免被居中或遮挡
      Scroll() {
        if (this.activeSubTabIndexes[0] === 0) {
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
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
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

      // 字符类型开关（直接引用 this.xxx 以建立状态观察）
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

      // 底部避让
      Row()
        .width('100%')
        .height(this.bottomContentInset)
    }
    .width('100%')
    .padding({ left: 8, right: 20, top: 8, bottom: 16 })
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
            .accessibilityText($r('app.string.username_email'))
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

      // 底部避让
      Row()
        .width('100%')
        .height(this.bottomContentInset)
    }
    .width('100%')
    .padding({ left: 8, right: 20, top: 8, bottom: 16 })
  }
}
