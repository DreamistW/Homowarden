import { ServerType } from "../utils/Constants";

/** 用户选择的托管区域及自托管地址。 */
export interface ServerConfig {
  serverType: ServerType,
  serverAddress: string // 仅自托管类型使用，可含协议和路径
}
