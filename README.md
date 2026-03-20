# Homowarden

Homowarden 是一个面向 HarmonyOS NEXT 的 Bitwarden 非官方客户端，使用 ArkTS 开发。

当前版本已经具备日常可用的密码库能力，包括登录、密码库同步、本地加密存储、密码项增删改查、TOTP 管理、生物识别解锁与自动锁定等核心功能。

## 项目现状

当前已经实现以下功能：

- Bitwarden 账户登录
- Bitwarden 官方服务器与自托管服务器接入
- 两步验证和新设备邮箱验证码流程
- 密码库从服务端拉取并同步到本地加密数据库
- 密码项的新增、查看、编辑、删除、回收站恢复
- 支持登录项、安全笔记、卡片、身份信息四类密码项
- 收藏、回收站、类型筛选与关键字搜索
- TOTP 验证码查看、录入、删除
- 支持通过扫描 `otpauth://` 二维码录入 TOTP 密钥
- 主密码解锁、生物识别解锁、自动锁定
- 对需要 `reprompt` 的条目进行主密码二次校验

此外，仓库中还包含一个与密码库无关的实验性工具页面“安心分享”，用于清洗常见平台分享链接并记录历史。

## 功能特性

### 账户与认证

- 支持 `bitwarden.com`
- 支持 `bitwarden.eu`
- 支持自托管 Bitwarden 服务
- 支持两步验证
- 支持新设备邮箱验证
- 支持记住邮箱

### 密码库

- 拉取并展示 Bitwarden 密码库
- 本地关系型数据库缓存
- 本地敏感字段加密存储
- 搜索密码项
- 按类型、收藏、回收站筛选
- 支持以下密码项类型：
    - 登录项
    - 安全笔记
    - 卡片
    - 身份信息
- 支持新增密码项
- 支持编辑密码项
- 支持删除密码项
- 支持从回收站恢复密码项

### TOTP

- 查看登录项的 TOTP 动态验证码
- 在独立列表页集中查看所有可用 TOTP
- 在新增/编辑登录项时维护 TOTP 密钥
- 解析 `otpauth://` 链接并提取密钥
- 扫码录入 TOTP

### 安全能力

- 主密码派生与本地校验
- 支持 PBKDF2 / Argon2id KDF 参数
- 使用关键资产区保存敏感数据
- 生物识别解锁
- 锁屏密码 / 指纹 / 人脸认证解锁
- 应用退到后台后自动锁定
- 对敏感条目执行主密码二次确认

## 主要页面

- `LoginPage`: 登录、服务器选择、两步验证、新设备验证
- `VaultPage`: 密码库首页，支持搜索、筛选、下拉刷新
- `AddCipherPage`: 新建密码项
- `CipherDetailPage`: 查看和编辑密码项详情
- `TotpListPage`: TOTP 验证码聚合列表
- `UnlockPage`: 主密码或生物识别解锁
- `SettingsPage`: 生物识别、自动锁定、注销等设置
- `Sure2SharePage`: 分享链接清洗工具
- `ShareHistoryPage`: 分享历史记录

## 项目结构

```text
entry/src/main/ets/
├── component/          # UI 组件
├── entryability/       # 应用入口 Ability
├── entrybackupability/ # 备份扩展入口
├── model/              # 数据模型
├── network/            # Bitwarden 网络接口
├── pages/              # 页面
├── utils/              # 加解密、数据库、资产、链接解析等工具
└── viewmodel/          # 页面状态与业务逻辑
```

## 技术栈

- ArkTS
- HarmonyOS NEXT
- `@ohos/axios`
- `@huozhiniao/argon2`
- `@abner/datastore`
- `@ibestservices/ibest-ui`
- `@nzy/logger`
- `CryptoArchitectureKit`
- `UserAuthenticationKit`
- `ArkData` 关系型数据库

## 已实现与待完善

### 已实现

- 核心登录流程
- 密码库同步与本地缓存
- 密码项 CRUD
- TOTP 管理
- 生物识别与自动锁定
- 基础设置页

### 待完善

- 文件夹等更多 Bitwarden 能力
- 更完善的导入导出 / 备份恢复能力
- UI 与交互细节打磨

## 注意事项

- 本项目为 Bitwarden 的非官方 HarmonyOS 实现
- 开源前请确认不要提交签名证书、私钥或其他敏感文件
- 应用内有提示：关键数据存储在关键资产区域，卸载前应先注销登录
- 自托管服务通常需要正确的 HTTPS 配置

## License

This project is licensed under the MIT License. See the LICENSE file for details.
