# PsyReaSFX 神经相似度组件

这是 PsyReaSFX 0.9.0 Beta 5 的可选 Windows x64 本地组件。它使用冻结的
EfficientAT `mn04_as` 模型生成音频 embedding，并通过 HNSW 加速全库相似声音召回。
音频始终留在本机，不会上传。

## 安装

1. 先通过 ReaPack 安装或更新到 PsyReaSFX 0.9.0 Beta 5。
2. 解压本 ZIP，双击 `Install-NeuralSimilarity.cmd`。
3. 安装完成后重新启动 PsyReaSFX。

默认安装到：

```text
%APPDATA%\REAPER\Scripts\PsyReaSFX\neural_similarity\
```

便携版 REAPER 可在 PowerShell 中指定资源目录：

```powershell
.\Install-NeuralSimilarity.ps1 -ReaperResourcePath "D:\REAPER Portable"
```

## 当前格式范围

神经路径目前只在本次搜索范围中的素材全部为 **32 kHz PCM16 WAV** 时启用。
其他采样率、位深或格式会自动使用原有 15 维声学特征检索，不影响基础功能。

首次全库检索会建立 embedding 缓存和 HNSW 索引，进度可见且可取消。之后会复用：

```text
<REAPER 资源目录>\Scripts\PsyReaSFX\neural_similarity\
```

## 卸载

双击 `Uninstall-NeuralSimilarity.cmd`。默认保留可重建缓存，以便以后重装。
若也要删除缓存，在 PowerShell 中运行：

```powershell
.\Uninstall-NeuralSimilarity.ps1 -RemoveCache
```

卸载或组件故障不会影响 PsyReaSFX；相似搜索会透明回退到基础算法。
