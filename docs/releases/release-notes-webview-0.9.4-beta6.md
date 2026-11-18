# PsyReaSFX 0.9.4 Beta 6 · Windows x64

## 中文

- 在详细波形上划出选区，然后按住选区或上方的手形条，把片段拖到 REAPER 或其他接受音频文件的应用。手形条会按选定的入点、出点和 Transfer 格式在 PRS 的 Transfer 目录生成文件。拖动边界可以微调选区，松开鼠标或按 Esc 可以取消准备。
- 修复 Windows 长路径上的素材被报为“文件不存在”、无法试听或无法生成波形的问题。读取原音频时继续允许其他程序同时访问。
- 音效库选单的普通项和选中项跟随界面主题显示。鼠标停在文件名上会显示完整来源路径，方便辨认不同文件夹里的同名素材。

使用 ReaPack 时，启用预发布、同步并更新 `PsyReaSFX.lua`，关闭并重新打开 PRS。离线安装请先关闭 REAPER，解压后运行 `Install-PsyReaSFX.cmd`。稳定版继续提供 0.9.3。

## English

- Draw a range in the detail waveform, then hold the selection or drag its hand grip into REAPER or another application that accepts audio files. The grip renders the captured in and out points in the configured Transfer format to the PRS Transfer directory. Drag either edge to trim the range. Release the mouse or press Esc to cancel preparation.
- Fixed waveform generation and playback for Windows media paths that previously appeared missing. Source reads allow other applications to access the original at the same time.
- Library menu entries follow the interface theme. Hover over a filename to see its full source path and distinguish identically named sounds in different folders.

In ReaPack, enable pre-releases, synchronize and update `PsyReaSFX.lua`, then reopen PRS. For offline installation, close REAPER, extract the ZIP and run `Install-PsyReaSFX.cmd`. The stable channel continues to serve 0.9.3.
