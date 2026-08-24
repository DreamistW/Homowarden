/** 生成器历史记录的类型 */
export enum GeneratorRecordType {
  PASSWORD = 'password',
  USERNAME = 'username'
}

/** 生成器历史记录数据模型 */
export interface GeneratorHistoryItem {
  id: string;
  content: string;
  type: GeneratorRecordType;
  timestamp: number;
}
