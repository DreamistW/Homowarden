/** 写入系统关键资产服务的秘密值及检索元数据。 */
export interface AssetModel {
  /** UTF-8 文本形式的令牌、密钥、KDF JSON 或其他敏感值。 */
  secret: string,
  alias: string,
  label?: string[]
}
