# ReaWebUI 重写：Beta 7 候选

本版以 Lua 0.9.2 Beta 4 为功能基准，重做菜单、设置和编辑交互，沿用原素材库与音频服务。按已确认的设计保留暗色、波形优先列表、默认隐藏序号、默认收起 FX，以及不受上方侧栏影响的底部全宽波形。

主要变化：

- 顶部菜单、左侧导航、素材箱、筛选条件和空状态有明确入口；错误有可见反馈。
- 设置改为九个分类、搜索、卡片和固定操作栏；修改先保存在草稿中，点击应用后写入。Enter 不会关闭窗口，切换分类或保存失败不会丢失输入。
- 集合、搜索、标签页和 Region 使用网页命名窗口；音效库、来源、保存搜索和集合管理继续使用旧版服务。
- Transfer 保留编辑中的参数，支持输出目录操作和实时任务进度；后台任务可分别取消。
- 减少重复分页和波形重绘；启动期间提供加载状态与可打开的设置页。
- 补齐中英文词条与 ReaPack 模块清单；生成的两种 Lua 入口均与模块源码同步。

安装包通过 [Beta 7 预发布页面](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.3-beta7) 提供。本地包位于 `dist/webview-rewrite/final/PsyReaSFX_WebView_0.9.3-beta7_win_x64.zip`，解压目录为 `dist/webview-rewrite/final/package/`。完整功能范围和验证边界见 [功能对照](WEBVIEW_PARITY_0_9_3_zh-CN.md)。此候选未安装到用户的正式 REAPER 环境；原生窗口验收仍未完成。

可复现的检查入口：

```powershell
./tools/Build-WebRelease.ps1 -OutputPath dist/beta7-check/package
./tools/Test-ReaPackVersionPolicy.ps1
./tools/Test-ReaPackWebView.ps1 -PackagePath dist/beta7-check/package -FixtureDirectory dist/beta7-check/reapack
./tools/Test-WebViewPackage.ps1 -PackagePath dist/beta7-check/package -FixtureDirectory dist/beta7-check/install
lua tools/lua_webview_selftest.lua dist/beta7-check/package/PsyReaSFX.lua <新的空测试目录>
node tools/webview_ui_selftest.cjs <Playwright模块目录> dist/beta7-check/package/web
```

构建和测试目录需要是新的空目录；Lua／Playwright 使用本地已安装的工具。浏览器测试截图写入 `dist/webview/verification/`，其中数据来自测试宿主。
