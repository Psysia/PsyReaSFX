# PsyReaSFX Desktop Preview

PsyReaSFX Desktop is a standalone Windows x64 companion to the REAPER-integrated edition. Preview 1 focuses on the core browse-to-REAPER loop: logical libraries with multiple source folders, incremental indexing, search, virtualized inline waveforms, detailed channel-aware waveform, click-to-seek preview, Artwork, favorites and Windows file drag into REAPER.

Download the latest package from [GitHub Releases](https://github.com/Psysia/PsyReaSFX/releases/latest). Extract the ZIP, then run `PsyReaSFX.Desktop.exe`. The package includes the Windows x64 .NET runtime and can coexist with the ReaPack edition.

The first preview is not feature parity with PsyReaSFX 0.7 Stable. Detailed waveform extraction is optimized for PCM/float WAV; compressed playback depends on Windows codecs. Metadata editing, saved searches, playlists, regions, loudness analysis, Transfer rendering and automatic updates remain on the desktop roadmap.

Local data is stored at `%LOCALAPPDATA%\PsyReaSFX Desktop\state.json`. Source audio remains read-only.
