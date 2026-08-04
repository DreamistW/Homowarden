import { CipherField } from '../model/CipherModels';
import { CipherFieldType } from '../utils/Constants';
import { AdaptiveIconButton } from './AdaptiveButton';

/**
 * 自定义字段编辑行
 * 按字段类型分支渲染名称输入、值输入与删除按钮，供新增/编辑密码项页面共用。
 * - TEXT：普通文本输入
 * - HIDE：密码输入，复用 ArkUI TextInput InputType.Password 自带的显示/隐藏眼睛图标
 * - BOOL：开关 + 是/否文案，值以 'true'/'false' 字符串序列化，与详情页 getFieldValue 解析保持一致；
 *   开关与文案由本地 @State 驱动，避免父组件就地 mutate 同一对象后 @Prop 不触发重渲
 */
@Component
export struct CustomFieldEditItem {
  @Prop field: CipherField;
  // 本地维护 BOOL 开关 UI 态，onChange 后立即刷新文案；避免依赖父组件对象引用变化。
  @State boolOn: boolean = false;
  onNameChange?: (name: string) => void;
  onValueChange?: (value: string) => void;
  onBoolChange?: (value: boolean) => void;
  onRemove?: () => void;

  aboutToAppear(): void {
    if (this.field.type === CipherFieldType.BOOL) {
      this.boolOn = this.field.value === 'true';
    }
  }

  build() {
    Row({ space: 8 }) {
      // 名称输入
      TextInput({
        text: this.field.name,
        placeholder: $r('app.string.cipher_field_name')
      })
        .fontSize(14)
        .width(112)
        .onChange((value: string) => {
          if (this.onNameChange) {
            this.onNameChange(value);
          }
        })

      // 按类型分支渲染值
      if (this.field.type === CipherFieldType.TEXT) {
        TextInput({
          text: this.field.value,
          placeholder: $r('app.string.cipher_field_value')
        })
          .fontSize(14)
          .layoutWeight(1)
          .onChange((value: string) => {
            if (this.onValueChange) {
              this.onValueChange(value);
            }
          })
      } else if (this.field.type === CipherFieldType.HIDE) {
        // ArkUI TextInput 在 InputType.Password 时自带显示/隐藏眼睛图标，无需再叠加自定义按钮。
        TextInput({
          text: this.field.value,
          placeholder: $r('app.string.cipher_field_value')
        })
          .fontSize(14)
          .type(InputType.Password)
          .layoutWeight(1)
          .onChange((value: string) => {
            if (this.onValueChange) {
              this.onValueChange(value);
            }
          })
      } else {
        // BOOL 类型：开关与文案都绑定本地 @State，切换即时刷新。
        Row({ space: 8 }) {
          Toggle({ type: ToggleType.Switch, isOn: this.boolOn })
            .accessibilityText($r('app.string.cipher_field_value'))
            .onChange((checked: boolean) => {
              this.boolOn = checked;
              if (this.onBoolChange) {
                this.onBoolChange(checked);
              }
            })

          Text(this.boolOn ? $r('app.string.common_yes') : $r('app.string.common_no'))
            .fontSize(14)
            .fontColor('#666666')
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
      }

      // 删除按钮
      AdaptiveIconButton({
        icon: $r('app.media.icon_delete'),
        accessibilityLabel: $r('app.string.accessibility_remove_field'),
        barWidth: 36,
        barHeight: 36,
        iconWidth: 18,
        iconHeight: 18,
        contentPadding: 4,
        barBottomMargin: 0,
        onButtonClick: () => {
          if (this.onRemove) {
            this.onRemove();
          }
        }
      })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }
}
