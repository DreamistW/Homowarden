# Argon2 OpenHarmony 适配包

`argon2-1.0.1-openharmony.har` 来自 OHPM 的 `@huozhiniao/argon2` 1.0.1：

- 上游：https://ohpm.openharmony.cn/ohpm/@huozhiniao/argon2/-/argon2-1.0.1.har
- 许可证：MIT，见 `LICENSE-argon2.txt`，HAR 内亦保留上游许可证。
- 将包级及 `nativeComponents` 的 `compatibleSdkType`、模块的 `compileSdkType` 改为 `OpenHarmony`。
- ARM64、x86_64 的 `libargon2.so` 和 `libc++_shared.so` 均保留原始二进制；没有重新编译或修改算法。
- 移除本地安装产生的 `oh_modules` 和锁文件，避免把机器缓存打入依赖包。

重新生成：

```powershell
python scripts/patch-argon2-openharmony.py upstream-argon2-1.0.1.har third_party/argon2-1.0.1-openharmony.har
```

修改标记后已通过 OH API 23 编译和 HAP 打包。尚未验证 OH 设备上的原生库加载、TaskPool 调用、Argon2id 标准向量及大内存参数；运行验证失败时再使用 OH Native SDK 重编译。
