# PsyReaSFX Desktop 0.7.23 Alpha 8 Light RC2

- Transfer captures each batch's settings, source paths and naming metadata, blocks ordinary normalized source-path overwrite, stages WAV/FLAC before commit, and retains existing outputs on failure or cancellation.
- FFmpeg stderr drains independently; cancelled jobs kill and wait for their own encoder process tree before cleaning temporary media.
- REAPER Bridge uses cancellation-aware requests, monotonic deadlines, response identity/size/number checks and unconditional queue cleanup. A rejected job no longer cancels a valid earlier task.
- Restore validates staged SQLite integrity and schema, checkpoints WAL, excludes concurrent readers/writers until replacement and retains a valid rollback copy. Rapid backups use unique names.
- Self-tests and benchmarks use isolated preferences, logs and waveform caches. The packaged self-test and production-service regressions pass.

Extract the entire ZIP and use **.NET 8 Desktop Runtime / Windows x64**, as in RC1. This remains a Desktop development release. Verification ran in the background; actual REAPER delivery and audio-device listening were not exercised.

中文：修复交付覆盖源路径、取消／编码失败破坏已有输出、批次参数随 UI 改变、Bridge 排队清理与数据库恢复失败路径；自测隔离真实偏好、日志和缓存。完整修复与路径别名等验证边界见随包 `WEBVIEW_HARDENING_BETA18_zh-CN.md`。
