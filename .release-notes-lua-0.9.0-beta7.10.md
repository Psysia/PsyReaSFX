# PsyReaSFX 0.9.0 Beta 7.10

This maintenance release fixes waveform generation for PCM/float WAV files stored at Windows paths of 260 characters or more.

The user's failed-task journal showed 330 waveform failures, and all 330 source paths exceeded the legacy Windows path limit. REAPER's peak API continued returning zero for those files even after the Init/Run/Finish sequence was corrected in Beta 7.9.

Beta 7.10 adds an internal long-path WAV reader for RIFF/RF64 PCM, IEEE float and WAVE_FORMAT_EXTENSIBLE audio. It opens the original file through the Windows `\\?\` extended-path form and builds waveform data incrementally across UI frames. Source audio is never copied, transcoded or modified. Normal paths and other formats continue to use REAPER's native source and peak APIs.

After updating through ReaPack, open `Settings → Reliability & recovery → Retry all failed tasks` to rebuild the existing failures.

Validation includes generated long-path fixtures and a real failed 96 kHz / 24-bit stereo WAV with a 331-character path, successfully producing 4,096 waveform points.
