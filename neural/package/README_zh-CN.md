# PsyReaSFX 神经相似度组件

这是 PsyReaSFX 0.9 Beta 的可选 Windows x64 本地组件。它使用冻结的
EfficientAT `mn04_as` 模型生成音频 embedding，并通过 HNSW 加速全库相似声音召回。
音频始终留在本机，不会上传。

## 推荐：通过 ReaPack 安装

**神经检索必须安装此包；基础声学检索和 AI 语义搜索不需要。
更新主脚本不会自动安装它。**

**[完整神经包 ZIP 精确下载 · Beta 7.13 · Windows x64 · 约 42.4 MB][neural-download]**
包含模型和安装脚本，不要只下载裸 EXE。

1. 导入并同步 [PsyReaSFX 仓库](https://github.com/Psysia/PsyReaSFX/raw/main/index.xml)。
2. 安装 `PsyReaSFX.lua`。
3. 打开 `扩展 → ReaPack → 浏览软件包 / Browse packages`，搜索独立数据包
   [PsyReaSFX Neural Similarity][neural-download]，启用
   **Enable pre-releases (bleeding-edge)**，在 **Versions** 选最新 Beta
   （当前 `0.9.0-beta7.13`），取消 **Pin current version**，点击 **Apply / OK**。
4. 重新启动 PsyReaSFX。

ReaPack 会把组件安装到 REAPER 的 `Data` 目录，并负责后续更新与卸载。可重建的
embedding 和 HNSW 缓存仍单独保存在 `Scripts/PsyReaSFX/neural_similarity`。

## 手动 ZIP 备用方式

1. 先通过 ReaPack 安装或更新 PsyReaSFX 0.9 Beta 主程序。
2. 下载[完整神经包 ZIP][neural-download]，全部解压后双击 `Install-NeuralSimilarity.cmd`。
3. 安装完成后重新启动 PsyReaSFX。

默认安装到：

```text
%APPDATA%\REAPER\Scripts\PsyReaSFX\neural_similarity\
```

便携版 REAPER 可在 PowerShell 中指定资源目录：

```powershell
.\Install-NeuralSimilarity.ps1 -ReaperResourcePath "D:\REAPER Portable"
```

## 音频格式支持

内建 Windows 路径支持常见采样率与 PCM16/PCM24/PCM32/float WAV，以及 AIFF、
FLAC、MP3、M4A。安装 FFmpeg 后还会启用 OGG、Opus、WavPack 与 CAF；可以设置
`PSYREASFX_FFMPEG` 指向程序、把 `ffmpeg.exe` 放在 sidecar 同目录，或加入 `PATH`。

音频只在内存中解码、下混并重采样到模型所需的 32 kHz，不会生成转换后的音频
副本。无法支持或损坏的单个文件会被跳过并报告，其他成功生成 embedding 的素材
仍可继续参与神经检索。

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

[neural-download]: https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0-beta7.13/PsyReaSFX_Neural_Similarity_v0_9_0_beta7_13_win_x64.zip
