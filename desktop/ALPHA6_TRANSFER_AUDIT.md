# PsyReaSFX Desktop Alpha 6 Transfer audit

Alpha 6 ports the Lua 0.7.23 Transfer workflow to the standalone Light build.
The acceptance target is behavioral parity for every operation that can be
performed without an active REAPER project.

## Connected

| Capability | Desktop Alpha 6 behavior |
|---|---|
| Output | Persistent independent directory, reveal controls and optional reveal after completion |
| Naming | Lua token set, safe Windows filenames, lowercase option and optional automatic variant suffix |
| Scope | Current waveform selection with full-file fallback; batch export uses complete sources |
| Formats | WAV 16/24/32-bit PCM; FLAC through `ffmpeg` available on `PATH` |
| Conversion | Source/44.1/48/96/192 kHz and source/mono/stereo channel layouts |
| Metadata | Best-effort preservation of common WAV chunks and adjacent metadata sidecars |
| Processing | Current Pitch, Rate, Gain, Reverse and Preserve Pitch rendered into output |
| Finishing | Fade in/out, Peak/True Peak/RMS-I/LUFS-I normalization, dither and noise shaping |
| Smart tail | Threshold, maximum duration and hold time applied to audio present after a source selection |
| Variants | Pitch/Rate/Gain/direction Cartesian generation; 16 values per field, 128 variants per asset, 4,096 jobs per run |
| Safety | Increment, skip and overwrite collision policies; temporary render cleanup; cancellation between items |
| Reporting | Live progress, success/skip/failure counts, latest output, TSV task report |
| Product | Chinese/English panel text, persistent settings, main-toolbar command and `Ctrl+T` |

## Verified by the packaged self-test

- A selected range is rendered as four forward/reverse Pitch variants.
- Automatic variant suffixes produce unique safe filenames.
- Lua's extended offline variant limits (`Pitch -48…+48`, `Rate 0.1…4`,
  `Gain -60…+24 dB`) are accepted.
- WAV output is mono, 44.1 kHz and 16-bit after resampling/channel conversion.
- Peak normalization, fades, dither and noise shaping run in the same job.
- An injected iXML source chunk is present in every exported WAV.
- A full-length FLAC file is produced and validated as a non-empty output.
- The task report is created and all jobs finish without failures.

## Standalone boundary

The desktop process has no active REAPER project, tracks, sends or Master bus.
Therefore source-tail analysis can extend only audio already present in the
source file. `Insert into REAPER after export`, project-FX rendering and BWF
spotting are Bridge-only operations and are not represented as misleading
standalone controls. A future optional REAPER Bridge will own that final gap.
