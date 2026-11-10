# Codex theme palette provenance

PRS Beta 13 exposes the 29 theme families registered in Codex desktop **26.1103.7773.0**, with **44 selectable variants (28 dark, 16 light)**. A family with only one variant keeps that tone in either mode; the picker labels this explicitly. System mode follows the OS where both variants exist. GitHub dark is the PRS default.

Names and the three color seeds were read as inert JSON data from the installed package. No Codex application code is embedded in PRS. The package contains 45 candidate theme chunks, but the actual menu/registry exposes 44 variants; unused chunks are excluded.

- Package `app.asar` SHA-256: `ee88fdd77fb7346efb5e91ce73c7c0eee4eba390ffba3192635d5cdbe44e4097`.
- Menu metadata: `webview/assets/async/93122.91c6d75720.js`.
- Theme registry and seed selection: `webview/assets/async/860717.54a5a14297.js`.
- When supplied, `chromeTheme.surface`, `chromeTheme.ink` and `chromeTheme.accent` take precedence. Otherwise background/foreground use the editor colors, and accent uses the registry's ordered chromatic-color candidates.
- PRS derives panel, raised, muted, divider and selection surfaces from these seeds. List and detailed waveform use the identical background. Settings support explicit background, foreground, accent and panel overrides. These are palette correspondences, not a claim that PRS renders the Codex interface.
- [Official Codex appearance reference](https://learn.chatgpt.com/docs/reference/settings).

| Theme | Mode | Background | Foreground | Accent |
| --- | --- | --- | --- | --- |
| Absolutely | dark | `#2d2d2b` | `#f9f9f7` | `#cc7d5e` |
| Absolutely | light | `#f9f9f7` | `#2d2d2b` | `#cc7d5e` |
| Ayu | dark | `#10141c` | `#bfbdb6` | `#e6b450` |
| Catppuccin | dark | `#1e1e2e` | `#cdd6f4` | `#cba6f7` |
| Catppuccin | light | `#eff1f5` | `#4c4f69` | `#8839ef` |
| Codex | dark | `#111111` | `#fcfcfc` | `#0169cc` |
| Codex | light | `#ffffff` | `#0d0d0d` | `#0169cc` |
| Dracula | dark | `#282a36` | `#f8f8f2` | `#ff79c6` |
| Everforest | dark | `#2d353b` | `#d3c6aa` | `#a7c080` |
| Everforest | light | `#fdf6e3` | `#5c6a72` | `#93b259` |
| GitHub | dark | `#0d1117` | `#e6edf3` | `#1f6feb` |
| GitHub | light | `#ffffff` | `#1f2328` | `#0969da` |
| Gruvbox | dark | `#282828` | `#ebdbb2` | `#458588` |
| Gruvbox | light | `#fbf1c7` | `#3c3836` | `#458588` |
| Linear | dark | `#0f0f11` | `#e3e4e6` | `#606acc` |
| Linear | light | `#fcfcfd` | `#1b1b1b` | `#5e6ad2` |
| Lobster | dark | `#111827` | `#e4e4e7` | `#ff5c5c` |
| Material | dark | `#212121` | `#eeffff` | `#80cbc4` |
| Matrix | dark | `#040805` | `#b8ffca` | `#1eff5a` |
| Monokai | dark | `#272822` | `#f8f8f2` | `#99947c` |
| Night Owl | dark | `#011627` | `#d6deeb` | `#44596b` |
| Nord | dark | `#2e3440` | `#d8dee9` | `#88c0d0` |
| Notion | dark | `#191919` | `#d9d9d8` | `#3183d8` |
| Notion | light | `#ffffff` | `#37352f` | `#3183d8` |
| OG | dark | `#343541` | `#d1d5db` | `#10a37f` |
| One | dark | `#282c34` | `#abb2bf` | `#4d78cc` |
| One | light | `#fafafa` | `#383a42` | `#526fff` |
| Oscurange | dark | `#0b0b0f` | `#e6e6e6` | `#f9b98c` |
| Proof | light | `#f5f3ed` | `#2f312d` | `#3d755d` |
| Raycast | dark | `#101010` | `#fefefe` | `#ff6363` |
| Raycast | light | `#ffffff` | `#030303` | `#ff6363` |
| Rose Pine | dark | `#232136` | `#e0def4` | `#ea9a97` |
| Rose Pine | light | `#faf4ed` | `#575279` | `#d7827e` |
| Sentry | dark | `#2d2935` | `#e6dff9` | `#7055f6` |
| Solarized | dark | `#002b36` | `#839496` | `#d30102` |
| Solarized | light | `#fdf6e3` | `#657b83` | `#b58900` |
| Temple | dark | `#02120c` | `#c7e6da` | `#e4f222` |
| Tokyo Night | dark | `#1a1b26` | `#a9b1d6` | `#3d59a1` |
| Vercel | dark | `#000000` | `#ededed` | `#006efe` |
| Vercel | light | `#ffffff` | `#171717` | `#006aff` |
| VS Code Plus | dark | `#1e1e1e` | `#d4d4d4` | `#007acc` |
| VS Code Plus | light | `#ffffff` | `#000000` | `#007acc` |
| Xcode | dark | `#1f1f24` | `#ffffff` | `#5482ff` |
| Xcode | light | `#ffffff` | `#000000` | `#0e0eff` |
