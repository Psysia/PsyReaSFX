# ReaWebAPI 更新流程

正式构建读取 `windows-x64.lock.json`。锁定上游 tag 对应的完整 commit、Windows 发行压缩包、原生 DLL 和匹配源码的 SHA-256。运行时、许可证和匹配源码一起进入离线安装包。

当前锁定 0.3.9.30，状态为 `native_acceptance_pending`，需要完成 REAPER 实机验收。

安装器默认拒绝新增或替换尚未通过实机验收的运行时。维护者在独立 REAPER 资源目录进行候选测试时，可显式传入 `-AllowUnverifiedRuntime`。正式发行需要将验收结果记录完整并晋升为 `native_accepted`。

## 评估上游版本

```powershell
./tools/New-ReaWebAPICandidate.ps1 -Tag v0.3.9.30
./tools/Build-WebRelease.ps1 -DependencyLockPath ./dist/reawebapi-candidates/0.3.9.30.lock.json -OutputPath ./dist/webview/candidate-0.3.9.30
```

候选工具只写独立清单，核验 GitHub 发布摘要和安装包结构。接口契约变动需要先调整适配器及测试，随后才能调整清单中的契约版本。

升级验证覆盖 Lua 后端、浏览器交互和安装回滚测试。REAPER 实机需要验证 WebView2 初始化、窗口重复打开和关闭、扫描及试听、缩略波形与选区、插入及 Transfer、原生拖出、封面读取、其他 ReaWebAPI 应用共存，以及重启后的版本诊断。通过后记录 REAPER、Windows、WebView2 版本及结果，将 `validation_status` 改为 `native_accepted`，再人工合入活动锁定清单。

## 用户机器上的版本

DLL 没有可读取的 PE 产品版本字段，因此安装器按 SHA-256 识别随包版本。遇到其他 DLL 时保留原文件。应用启动后通过 `lifecycle.ready` 读取真实版本，并检查 protocol、runtime contract、web contract 和消息容量。兼容的外部版本会显示待验证提示，契约冲突会停止连接并提供恢复指引。

关闭 REAPER 后可用安装器的 `-UseBundledRuntime` 显式切回随包候选版本。安装事务会保存应用与被替换 DLL，回滚时保护后续被外部修改的共享扩展。安装过程使用独占锁、临时目录、原子 DLL 替换及持久化事务记录。中断事务会在下一次安装时恢复。

## 分发

安装包中的 `licenses/reawebapi` 保留上游许可证和第三方声明，`sources` 包含对应 commit 的完整源码归档。ReaWebAPI 作为独立 DLL 安装到 REAPER UserPlugins，继续保留替换能力。Windows 还需提供其依赖的 Microsoft Edge WebView2 Runtime。

安装器兼容 Windows PowerShell 5.1，并在写入安装状态前检查目标与备份路径长度。资源目录过深时需改用较短路径。

上游资料见 [ReaWebAPI 仓库](https://github.com/zaibuyidao/ReaWebAPI) 和 [固定版本许可证](https://github.com/zaibuyidao/ReaWebAPI/blob/f3d83ee333a5df0f1242b20efc706ce5a893dabf/LICENSE.md)。
