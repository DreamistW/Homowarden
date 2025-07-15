# Homowarden - Bitwarden HarmonyOS 应用

这是一个适用于HarmonyOS NEXT平台的Bitwarden密码管理器客户端应用，使用ArkTS语言开发。

## 功能特性

### 登录功能
- 支持Bitwarden官方服务器（US/EU）
- 支持自托管服务器
- 完整的登录流程
- 输入验证和错误处理
- 状态管理和UI响应

## 项目结构

```
entry/src/main/ets/
├── component/           # UI组件
├── entryability/        # 应用入口
├── model/              # 数据模型
│   ├── AccessTokenRequest.ets
│   ├── AccessTokenResponse.ets
│   ├── PreloginRequest.ets
│   └── PreloginResponse.ets
├── network/            # 网络请求
│   ├── AuthApi.ets
│   └── HttpClient.ets
├── pages/              # 页面
│   ├── Index.ets
│   └── LoginPage.ets   # 登录页面
├── utils/              # 工具类
│   ├── Constants.ets       # 常量定义
│   ├── Crypto.ets          # 加密工具类
│   └── DeviceUtil.ets      # 设备信息类
├── viewmodel/          # 视图模型
│   └── LoginViewModel.ets
```

## 登录流程

1. **输入验证**: 验证邮箱、密码和服务器地址
2. **预登录**: 获取KDF参数（密钥派生函数参数）
3. **主密钥派生**: 使用PBKDF2/Argon2id派生主密钥
4. **用户密钥派生**: 从主密钥派生用户密钥
5. **登录**: 使用用户名密码获取访问令牌
6. **状态管理**: 保存登录信息并更新UI状态


## 服务器配置

### 支持的服务器类型
- **US**: `https://identity.bitwarden.com` (默认)
- **EU**: `https://identity.bitwarden.eu`
- **自托管**: 用户自定义服务器地址

### 自托管服务器
用户可以选择"Self-hosted"选项，然后输入自己的Bitwarden服务器地址。

## 待实现功能

- [ ] 密码库查看
- [ ] 本地存储（使用preferences或RDS）
- [ ] 自动登录
- [ ] 生物识别认证
- [ ] 密码库同步
- [ ] 密码生成器
- [ ] 安全笔记

## 技术栈

- **语言**: ArkTS
- **网络**: Axios
- **UI组件**: IBest-UI
- **加解密**: CryptoArchitectureKit、@ohos/crypto-js和@huozhiniao/argon2
- **日志**: @nzy/logger

## 注意事项

1. 确保网络权限配置正确
2. 自托管服务器需要HTTPS支持
3. 登录信息需要安全存储
4. 遵循ArkTS的最佳实践，避免使用any类型
5. 加密密钥需要安全管理
6. 敏感数据使用完毕后要及时清理
