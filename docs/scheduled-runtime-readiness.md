# ReaWebAPI checks on each update

Every push, manual run, and scheduled run checks the latest release from
`zaibuyidao/ReaWebAPI` and the corresponding Windows mirror in `Psysia/ReaWebAPI`.
The check records the tag, commit, and readiness in the job summary.

- When the mirror is ready, the workflow verifies the checked candidate with
  the existing provenance, compatibility, package, rollback, and browser tests.
- When a release or source sync is still pending, scheduled runs record
  **WAITING**. Push and manual runs use the pinned runtime for package and
  browser tests. Latest-runtime validation is recorded as deferred.
- API errors, mismatched assets, and test failures still fail the workflow.

Run `./tools/Sync-ReaWebAPIFork.ps1` before updating PRS or PsyReaWwise. The
signed-in GitHub account can fast-forward the fork's `main` and request a
verified release mirror. GitHub Actions can mark a sync as waiting when an
upstream workflow change requires write permission. The `psyreasfx` branch
holds the fork automation and compatibility patches. Integrate upstream
changes into that branch when preparing a tested patch release.

The runtime packaged with PRS and PsyReaWwise comes from the dependency lock.
Promote a candidate after native REAPER acceptance.

# 每次更新检查 ReaWebAPI

每次推送、手动运行和计划任务都会检查 `zaibuyidao/ReaWebAPI` 已发布的版本，以及
`Psysia/ReaWebAPI` 对应的 Windows 镜像。工作流摘要记录标签、提交和就绪状态。

- 镜像就绪后，验证该版本的来源、兼容性、打包、回滚和浏览器行为。
- 镜像或源码正在同步时，计划任务记录 **等待**。推送和手动运行使用固定运行时验证
  打包和浏览器行为，最新运行时将在镜像就绪后验证。
- API 错误、资产校验失败和测试失败仍会报告失败。

更新 PRS 或 PsyReaWwise 前运行 `./tools/Sync-ReaWebAPIFork.ps1`。已登录的 GitHub
账号负责快进 fork 的 `main` 并请求发布校验过的镜像。上游修改工作流而需要写入权限时，
GitHub Actions 会记录等待。 `psyreasfx` 分支保存同步工作流和兼容补丁，准备补丁版时
再合并并验证上游变更。

PRS 和 PsyReaWwise 发行包按依赖锁选择运行时。候选版通过原生 REAPER 验收后才能升级随包版本。
