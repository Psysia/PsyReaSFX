# PsyReaSFX 0.9.0 Beta 5

本版本把可选的本地神经相似度路径正式接入 Lua，并提供可直接安装的 Windows x64 自包含组件。

## 新功能

- 使用冻结的 EfficientAT `mn04_as` 320 维 embedding 提升相似声音表达能力。
- 全库搜索使用持久化 HNSW 召回；当前结果范围保持精确候选过滤。
- embedding 与原有时长、起音、瞬态、包络等 15 维声学特征混合重排，固定返回 Top-200。
- 启动探测、任务准备、进度、取消、缓存复用和结果轮询均避免阻塞 REAPER 主界面。

## 安全回退与隐私

- 神经组件完全可选且只在本机运行，不上传音频。
- 未安装、格式不兼容、模型或协议不匹配、任务失败/超时、缓存或结果损坏时，透明回退到原有 15 维检索。
- 协议 v1 当前只在完整搜索范围全部为 32 kHz PCM16 WAV 时启用；其他素材不受影响。

## 安装

- ReaPack 用户启用单包预发布后，可直接更新到 `0.9.0-beta5`。
- 若要启用神经路径，另行下载 `PsyReaSFX_Neural_Similarity_v0_9_0_beta5_win_x64.zip`，解压并运行 `Install-NeuralSimilarity.cmd`。
- 可选组件为 Windows x64 自包含程序，不要求另装 .NET；包内附带卸载脚本、模型与第三方许可。

## 验证

- Lua 回归覆盖神经协议、自动回退和 50 万签名容量门槛。
- sidecar 覆盖模型金样、增量 FP16 缓存、HNSW、Recall@20、取消、损坏恢复与真实文件任务。
- 发布包增加构建一致性、自检以及安装/卸载 smoke test。

---

Beta 5 adds an optional, fully local EfficientAT similarity path with incremental FP16 embeddings, persistent HNSW recall, hybrid acoustic reranking, visible progress, cancellation, and transparent fallback to the dependency-free 15-feature search. The neural path currently activates only for complete scopes of 32 kHz PCM16 WAV files. A separate self-contained Windows x64 component is included as an optional release asset; no separate .NET installation is required and audio is never uploaded.
