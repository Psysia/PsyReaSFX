# PsyReaSFX Desktop 0.7.23 Alpha 7 Light Hotfix 1 audit

This hotfix closes two incorrectly optimistic parity claims from Alpha 7.

## Channel audition

- CH 1…CH N is passed into both the current preview rebuild and the next file open.
- A selected source channel is routed as dual mono, so the result is audible on both speakers without leaking other source channels.
- The detail waveform filters its lanes using the same zero-based channel selection and retains the source-channel label.
- The packaged self-test feeds a deterministic four-channel stream into CH 3 isolation and verifies the exact left/right output samples.

## Waveform-cache directory

- The active cache path persists in Desktop preferences and is available under Settings → Maintenance.
- Inline and high-resolution waveform generation writes RWF3 files into the active directory.
- Existing caches may be copied and validated before source-cache deletion, or the application can switch paths while leaving old files untouched.
- Parent/child directory migrations are rejected to prevent recursive or ambiguous moves.
- Changing paths clears only in-memory waveform entries and reloads the selected asset; source audio is never moved or edited.
- The packaged self-test generates a cache in a custom directory, migrates it, validates the destination and confirms the source copy was removed only after validation.

## Verified result

Release build: 0 errors. Packaged regression self-test: passed, including channel isolation, waveform channel state and custom-cache write/migration.
