# ReaWebAPI 更新流程

正式构建读取 `windows-x64.lock.json`。依赖下载统一走 [Psysia/ReaWebAPI](https://github.com/Psysia/ReaWebAPI)，锁定 tag 对应的完整 commit、Windows 发行压缩包、原生 DLL 和匹配源码的 SHA-256。运行时、许可证和匹配源码一起进入离线安装包。历史发行 tag 保持原样。

验证历史 ReaPack 在线载荷时，`Test-ReaPackWebView.ps1 -Online` 从对应发行 tag 读取原始锁定清单；浅克隆需先获取这些 tag，避免将主分支新的镜像地址误认为历史载荷被修改。

当前锁定 0.3.9.30，状态为 `native_acceptance_pending`，需要完成 REAPER 实机验收。

安装器默认拒绝新增或替换尚未通过实机验收的运行时。维护者在独立 REAPER 资源目录进行候选测试时，可显式传入 `-AllowUnverifiedRuntime`。正式发行需要将验收结果记录完整并晋升为 `native_accepted`。

## 开发时自动使用最新版

```powershell
./tools/Build-WebDevelopment.ps1
```

每次执行先查询作者最新正式 Release 和源码 main；Fork 落后时，通过已登录的 GitHub CLI 立即触发同步并等待，随后从自己的 Fork 校验并下载对应版本、生成独立候选锁和可安装开发 ZIP。产物写入新的 `dist/webview-development/<时间>-<随机值>` 目录。已有版本复用 SHA-256 校验过的缓存。首次需要安装 GitHub CLI 并执行 `gh auth login`；构建流程不会复制个人令牌到 GitHub Secrets。

这里的“最新版”是作者发布的最新正式 Release。未发布的 main 提交也会同步到 Fork，但不会冒充已发布 DLL。应用要求的 protocol、runtime contract、web contract 或消息容量不兼容时，构建停止并要求先修改适配器。

[WebView latest runtime](https://github.com/Psysia/PsyReaSFX/actions/workflows/development-webview.yml) 在相关开发改动推送到 main、codex/*、beta/* 时自动构建，也可手动运行；每半小时检查是否出现新依赖。定时检查会跳过已成功验证的相同代码和上游版本组合。通过安装/回滚和浏览器交互检查后，Actions 的 Artifacts 提供开发 ZIP、校验文件和候选锁，保留 14 天。正式发布仍读取活动锁，以便复现及回滚；自动检查不会将实机验收状态改成已通过。

CI 使用只读仓库令牌，等待 Fork 自己的定时同步，最多 10 分钟；超时会明确失败，不会悄悄改用旧版。GitHub 定时工作流可能延迟，此时可在 Fork 手动运行同步后重新执行构建。本地命令拥有已登录账号权限时可以立即触发同步。

## Fork 如何跟随作者

- `main` 保持作者 main 的源码镜像，只允许快进，遇到分叉停止。
- 默认分支 `psyreasfx` 保留自己的同步工具，并合并作者 main；冲突时停止，保留现有提交。
- [Sync upstream ReaWebAPI](https://github.com/Psysia/ReaWebAPI/actions/workflows/sync-upstream.yml) 每半小时运行，也支持指定 tag 手动同步。首次已镜像 v0.3.9.30 与 v0.3.9.32。
- 作者未改动的 Windows ZIP/DLL 直接镜像，避免重复编译；同版本 tag 指向同一源码提交。发布前核对上游 SHA-256、DLL、许可证、匹配源码及声明的接口契约，附上 `mirror-manifest.json`。已发布资源不覆盖。
- 上游原有的多平台构建工作流在 Fork 中关闭；`tools/reawebapi-fork/` 保存本次部署的同步脚本、测试和工作流模板，运行副本位于 Fork 的 `.github/psysia` 和 `.github/workflows`。后续修改工具时需同步这两个位置。

如果以后修改 ReaWebAPI 原生代码，应在 `psyreasfx` 保留补丁并另行编译带自有后缀的版本，同时更新匹配源码和验证记录；当前镜像包明确标记 `modified: false`，不包含分支上的原生补丁。

## 单独评估指定版本

```powershell
./tools/New-ReaWebAPICandidate.ps1 -Tag latest
# 也可指定 -Tag v0.3.9.32；以下路径使用输出中实际解析到的版本。
./tools/Build-WebRelease.ps1 -DependencyLockPath ./dist/reawebapi-candidates/0.3.9.32.lock.json -OutputPath ./dist/webview/candidate-0.3.9.32
```

候选工具只写新的独立清单，核验 Fork 发布摘要、来源清单、匹配源码及安装包结构。`-Tag latest` 解析 Fork 已镜像的最新版；需要即时核对作者版本时使用上面的开发构建命令。接口契约变动需要先调整适配器及测试，随后才能调整活动清单中的支持范围。

升级验证覆盖 Lua 后端、浏览器交互和安装回滚测试。REAPER 实机需要验证 WebView2 初始化、窗口重复打开和关闭、扫描及试听、缩略波形与选区、插入及 Transfer、原生拖出、封面读取、其他 ReaWebAPI 应用共存，以及重启后的版本诊断。通过后记录 REAPER、Windows、WebView2 版本及结果，将 `validation_status` 改为 `native_accepted`，再人工合入活动锁定清单。

## 用户机器上的版本

DLL 没有可读取的 PE 产品版本字段，因此安装器按 SHA-256 识别随包版本。遇到其他 DLL 时保留原文件。应用启动后通过 `lifecycle.ready` 读取真实版本，并检查 protocol、runtime contract、web contract 和消息容量。兼容的外部版本会显示待验证提示，契约冲突会停止连接并提供恢复指引。

关闭 REAPER 后可用安装器的 `-UseBundledRuntime` 显式切回随包候选版本。安装事务会保存应用与被替换 DLL，回滚时保护后续被外部修改的共享扩展。安装过程使用独占锁、临时目录、原子 DLL 替换及持久化事务记录。中断事务会在下一次安装时恢复。

## 分发

安装包中的 `licenses/reawebapi` 保留上游许可证和第三方声明，`sources` 包含对应 commit 的完整源码归档。ReaWebAPI 作为独立 DLL 安装到 REAPER UserPlugins，继续保留替换能力。Windows 还需提供其依赖的 Microsoft Edge WebView2 Runtime。

安装器兼容 Windows PowerShell 5.1，并在写入安装状态前检查目标与备份路径长度。资源目录过深时需改用较短路径。

上游资料见 [ReaWebAPI 仓库](https://github.com/zaibuyidao/ReaWebAPI) 和 [固定版本许可证](https://github.com/zaibuyidao/ReaWebAPI/blob/f3d83ee333a5df0f1242b20efc706ce5a893dabf/LICENSE.md)。
