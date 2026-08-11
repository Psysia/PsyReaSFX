# PsyReaSFX Desktop 0.7.23 Alpha 7 Light Hotfix 2 audit

## Scope

This hotfix replaces the operating-system Help message box with a PsyReaSFX
Help Center and preserves all Alpha 7 Hotfix 1 channel and cache-path work.

## Verified behavior

- Help no longer creates a default light Windows message box.
- The Help Center uses the live shell palette, brand icon, Orbitron wordmark,
  card spacing, dark controls and application scrollbar styling.
- It is modeless and single-instance: reopening Help activates the existing
  window instead of stacking duplicates or blocking the browser.
- Quick start, search syntax, audition/waveform operation, organization and
  shortcuts are separated into concise pages.
- Simplified Chinese and English are both validated by the packaged UI smoke
  test.
- Escape and both branded close controls dismiss Help; the window remains
  resizable and centered on the main application.

## Non-goals

The in-app Help Center is a concise operational reference. Long-form setup,
data safety, Transfer details and troubleshooting remain in the packaged
README and parity documents.
