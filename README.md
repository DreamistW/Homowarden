# Homowarden

Homowarden 是一个面向 OpenHarmony API 23 及以上标准系统 的 Bitwarden 非官方客户端，使用 ArkTS 开发，支持标准系统设备、平板和 2in1 设备。

当前为 `openharmony` 移植分支，包名 `com.dreamist.homowarden_oh`，与 HarmonyOS 版本独立安装。本地构建方式见下文。

项目已经具备日常可用的密码库能力，包括账户认证、密码库同步、本地加密存储、密码项管理、TOTP、密码与用户名生成、生物识别解锁和自动锁定等核心功能，并针对宽屏和 PC 使用场景进行了适配。

## 项目现状

当前已经实现以下功能：

- Bitwarden 账户登录
- Bitwarden 官方服务器与自托管服务器接入
- 两步验证和新设备邮箱验证码流程
- 密码库从服务端拉取并同步到本地加密数据库
- 密码项的新增、查看、编辑、删除、回收站恢复
- 支持登录项、安全笔记、卡片、身份信息四类密码项
- 支持密码项收藏、自定义字段、多网址和敏感条目二次验证
- 收藏、回收站、类型筛选、关键字搜索与常用字段快捷复制
- TOTP 验证码查看、录入、编辑、删除
- 支持手动输入 TOTP 密钥、安全粘贴，以及相机扫码和相册二维码导入
- 密码与用户名生成器，以及生成历史管理
- 主密码解锁、生物识别解锁、自动锁定
- 中英文界面、无障碍语义与系统语言变化响应
- 手机底部导航、宽屏侧栏和密码库列表/详情分栏布局
- 脱敏日志导出与登录问题反馈入口

此外，应用还包含一个与密码库无关的实验性工具页面“安心分享”，用于清洗常见平台分享链接，并支持搜索、复制和批量删除历史记录。

## 功能特性

### 账户与认证

- 支持 `bitwarden.com`
- 支持 `bitwarden.eu`
- 支持自托管 Bitwarden 服务
- 支持两步验证
- 支持新设备邮箱验证
- 支持记住邮箱
- 防止登录、验证等认证请求重复提交

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
- 支持永久删除回收站中的密码项
- 支持收藏与取消收藏
- 支持文本、隐藏和布尔类型的自定义字段
- 支持为登录项维护多个网站地址
- 支持右键菜单和用户名、密码、TOTP 等常用字段快捷复制

### TOTP

- 查看登录项的 TOTP 动态验证码
- 在独立列表页集中查看所有可用 TOTP
- 在新增/编辑登录项时维护 TOTP 密钥
- 解析 `otpauth://` 链接并提取密钥
- 手动输入、粘贴、相机扫码或相册图片导入 TOTP（OH 真机待验证）

### 密码与用户名生成器

- 使用系统安全随机源生成密码
- 支持长度、大小写字母、数字、符号和最小字符数配置
- 支持生成随机单词用户名和邮箱别名
- 可在新增/编辑登录项时直接生成并回填用户名或密码
- 保存生成历史，并支持复制、单项删除和清空

### 多设备与交互

- 支持 `phone`、`tablet`、`2in1`
- 手机使用悬浮底部导航，宽屏设备使用侧栏导航
- 平板横屏和大窗口采用密码库列表/详情分栏布局
- 支持键盘提交、列表快捷操作和未保存修改离开确认
- 2in1 密码库支持右键快捷菜单

### 安全能力

- 主密码派生与本地校验
- 支持 PBKDF2 / Argon2id KDF 参数
- 使用关键资产区保存敏感数据
- 生物识别解锁
- 锁屏密码 / 指纹 / 人脸认证解锁
- 应用退到后台后自动锁定
- 对敏感条目执行主密码二次确认
- 支持截屏保护和后台隐私遮罩
- 注销时清理本地密码库、生成历史和登录凭据
- 导出日志前对令牌、密码、Cookie 等敏感诊断信息进行脱敏

### 安心分享

- 清洗常见平台分享文案并提取链接
- 支持复制完整清洗结果或仅复制链接
- 保存分享历史并支持搜索
- 支持多选、全选和批量删除历史记录

## 主要页面

- `LoginPage`: 登录、服务器选择、两步验证、新设备验证
- `VaultPage`: 密码库首页，支持搜索、筛选、下拉刷新
- `AddCipherPage`: 新建密码项
- `CipherDetailPage`: 查看和编辑密码项详情
- `TotpListPage`: TOTP 验证码聚合列表
- `GeneratorPage`: 密码与用户名生成器
- `GeneratorHistoryPage`: 生成历史记录
- `UnlockPage`: 主密码或生物识别解锁
- `SettingsPage`: 生物识别、自动锁定、安全、账户、日志导出等设置
- `Sure2SharePage`: 分享链接清洗工具
- `ShareHistoryPage`: 分享历史记录

## 项目结构

```text
entry/src/main/ets/
├── component/          # UI 组件
├── domain/             # 领域展示映射
├── entryability/       # 应用入口 Ability
├── entrybackupability/ # 备份扩展入口
├── localization/       # 语言状态与本地化工具
├── model/              # 数据模型
├── network/            # Bitwarden 网络接口
├── pages/              # 页面
├── utils/              # 加解密、数据库、资产、链接解析等工具
└── viewmodel/          # 页面状态与业务逻辑
```

## 技术栈

- ArkTS
- ArkUI
- OpenHarmony API 23+
- `@ohos/axios`
- `@huozhiniao/argon2`
- `@abner/datastore`
- `@nzy/logger`
- `CryptoArchitectureKit`
- `UserAuthenticationKit`
- ZBar 原生二维码解码、`CameraKit`、`ImageKit` 与公共 PhotoViewPicker
- `ArkData` 关系型数据库

## 已实现与待完善

### 已实现

- 核心登录流程
- 密码库同步与本地缓存
- 密码项 CRUD
- 收藏、自定义字段和密码项快捷操作
- TOTP 管理与离线二维码导入
- 密码和用户名生成器
- 生物识别与自动锁定
- 手机、平板和 2in1 自适应布局
- 中英文界面和无障碍支持
- 分享历史与生成历史管理
- 脱敏日志导出

### 待完善

- 文件夹等更多 Bitwarden 能力
- 更完善的导入导出 / 备份恢复能力
- 更完整的自动化测试覆盖
- UI 与交互细节打磨

## 注意事项

- 本项目为 Bitwarden 的非官方 OpenHarmony 实现
- 本项目尚未经过独立安全审计，不应作为密码数据的唯一备份
- 应用内有提示：关键数据存储在关键资产区域，卸载前应先注销登录
- 自托管服务通常需要正确的 HTTPS 配置
- Vaultwarden 的 `DOMAIN` 应设置为客户端实际访问的完整地址（包括非标准端口和子路径）。对于 `/api/config` 返回同一基础地址下 `/api`、`/identity` 标准端点的部署，应用沿用用户填写的服务器地址，兼容反向代理与容器地址不一致的情况；独立域名或自定义路径的端点仍按服务端配置解析。

## 本地构建

安装 OpenHarmony API 23 SDK、JDK 和 DevEco CLI，并配置本机的 `JAVA_HOME`、`OHOS_BASE_SDK_HOME`。
首次检出后，在项目根目录复制公开构建模板：

```powershell
Copy-Item build-profile.example.json5 build-profile.json5
devecocli.cmd build --modules entry@default
```

模板保留 SDK、产品和模块配置，不包含签名材料。需要安装到设备时，在本机配置自己的
`debug` 签名；签名材料放在用户目录的 `.ohos/config` 或其他本地忽略路径。
`build-profile.json5` 仅在本地使用，不提交到 Git。

## License

This project is licensed under the MIT License. See the LICENSE file for details.
