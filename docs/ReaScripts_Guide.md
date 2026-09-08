# Psysia ReaScripts Guide

> A collection of practical REAPER scripts for sound-design editing, track organization, and rendering workflows.
>
> Author: Psysia  
> Repository: Psysia/PsyReaSFX

[中文使用手册](./ReaScripts_Guide_zh-CN.md)

---

## Installation

### Install with ReaPack

In REAPER, open:

`Extensions → ReaPack → Import repositories...`

Add this repository index:

```text
https://raw.githubusercontent.com/Psysia/PsyReaSFX/main/index.xml
```

Then run:

`Extensions → ReaPack → Synchronize packages`

Search for `Psysia`, `psy_`, or the script name in ReaPack.

### Manual installation

The scripts are stored under:

```text
Scripts/Psysia/
```

Copy the `.lua` files into the `Scripts` folder inside your REAPER Resource Path, then load them through:

`Actions → Show action list → New action → Load ReaScript...`

For frequently used scripts, assigning keyboard shortcuts or toolbar buttons is recommended.

---

# Current Scripts

## 1. Create Folder Region and Render Matrix

Current version: **2.4**

File:

```text
psy_Create Folder Region and Render Matrix_创建文件夹区域与渲染矩阵.lua
```

### What it does

Automatically creates or updates rendering Regions from the current media-item or track selection. It can:

1. calculate the render time range;
2. resolve the source tracks and folder hierarchy;
3. create or update a Region;
4. name the Region from the appropriate folder track;
5. write the correct track to the Region Render Matrix.

### Folder resolution rules

- If a single source track is itself a folder track, that track is used.
- If a single source track is inside a folder, its direct parent folder is used.
- For multiple source tracks, the script searches for their nearest common parent.
- Multiple logical Regions may share exactly the same time range.
- A Region is treated as the same logical Region only when both its time range and Render Matrix target match.

### Typical use

Select a group of layered sound-design items that should be exported as one asset, then run the script.

Useful for:

- layered game-audio assets;
- folder-bus rendering;
- Region Render Matrix batch export;
- automatic naming in nested folder structures.

### Note

The script modifies Regions and the Region Render Matrix. Verify the selection before running it in a production project.

---

## 2. Sort Tracks by Earliest Item Position

Current version: **1.3**

File:

```text
psy_Sort Selected Tracks by Earliest Item Position_按最早素材位置排序选中轨道.lua
```

### What it does

Sorts relevant tracks from top to bottom according to the earliest item position on the timeline.

### Two operating modes

#### A. Media items are selected

Selected items always take priority over selected tracks.

The script will:

1. detect the tracks containing the selected items;
2. when multiple selected items are on the same track, use the earliest selected item on that track;
3. sort those tracks by that position.

You do not need to manually select the tracks first.

#### B. No items are selected, but tracks are selected

The script scans all items on each selected track and uses the earliest item on that track as the sorting key.

### Additional behavior

- Equal positions preserve the original relative track order.
- Non-contiguous selected tracks preserve their original destination slots where possible.
- Folder-ending relationships are preserved during reordering.
- Original track selection is restored after execution.

### Typical use

After arranging multiple skill, animation, UI, or layered SFX elements vertically, select the relevant media items and run the script to make the track order follow the sound-entry order.

---

## 3. Open Render Dialog with Auto Tail

Current version: **1.0**

File:

```text
psy_Open Render Dialog with Auto Tail_打开渲染对话框并应用自动尾音.lua
```

### What it does

Use this script instead of the normal:

`File → Render`

When the auto-tail feature is enabled, the script first applies the saved tail settings to the current project and then opens REAPER's native Render dialog.

It manages:

- maximum render-tail duration;
- Trim ending silence;
- silence-trim threshold;
- safety padding after the trim point;
- Tail Flags for different Render Bounds modes.

### Default settings

If no user values have been saved, the defaults are:

- Max Tail: 12 seconds;
- Trim Threshold: -60 dBFS;
- Safety Padding: 80 ms.

### Recommended use

If you already use Smart Tail Render Panel to configure your tail settings, bind this script to your normal Render shortcut and use it as your everyday entry point to the Render dialog.

---

## 4. Smart Tail Render Panel

Current version: **1.1**

File:

```text
psy_Smart Tail Render Panel_智能尾音渲染面板.lua
```

### What it does

Uses REAPER's native Render Tail and Trim ending silence features to reduce hard truncation of reverb, delay, or long-decay sounds during batch rendering.

Conceptually:

```text
Original render bounds
→ render additional maximum tail
→ trim ending silence using a dBFS threshold
→ add a small safety pad
```

### Adjustable parameters

- **Threshold**: determines when the tail is considered quiet enough to trim;
- **Max Tail**: maximum extra duration that may be rendered;
- **Safety**: additional time preserved after the trim point;
- **Trim**: enables or disables ending-silence trimming;
- **Pad**: enables or disables safety padding;
- **Scope**: controls whether Tail settings apply to the current render bounds, Regions, or all supported bounds.

### Defaults

- Threshold: -60 dBFS;
- Max Tail: 10 seconds;
- Safety: 200 ms.

### Important routing note

This script only solves render-bound truncation. It does not change routing.

If reverb or delay lives on a separate return track, that return must feed the bus being rendered, or the return itself must be included in the selected render source. Otherwise the tail may still be absent from the rendered file.

The script does not require SWS, ReaPack, or ReaImGui at runtime.

---

## 5. Remove Gaps Between Selected Items

Current version: **1.0**

File:

```text
psy_Remove Gaps Between Selected Items_移除选中素材间隙.lua
```

### What it does

Moves multiple selected media items so that each item starts exactly at the end of the previous one.

```text
Item A    Item B       Item C
[-----]   [----]       [---]

↓

[-----][----][---]
```

### Note

This directly changes item positions on the timeline. Use it on an item set whose intended order is already confirmed. The operation can be undone with `Ctrl+Z`.

---

## 6. Toggle LUFS-M and Spectrogram

Current version: **1.0**

File:

```text
psy_Toggle LUFS-M and Spectrogram_切换LUFS-M与频谱图.lua
```

### What it does

Switches between two Peaks-display modes:

1. Spectral Peaks + Momentary Loudness graph (LUFS-M);
2. Spectrogram.

The script searches the REAPER Action List by action name instead of relying on a hard-coded machine-specific Command ID.

This makes it more robust when keyboard configurations or action IDs change.

### Note

The script requires a REAPER version that supports action-enumeration APIs.

If the script reports that it cannot find an action, verify that the corresponding English action names are still present in the Action List.

---

## 7. Create Folder from Selected Tracks with Pro-L 2

Current version: **1.0**

File:

```text
psy_Create Folder from Selected Tracks with Pro-L 2_从选中轨道创建文件夹并挂载Pro-L 2.lua
```

### What it does

After selecting a group of tracks, the script:

1. creates a new parent track above the first selected track;
2. wraps the selected tracks inside that folder;
3. names the parent track `Folder Bus`;
4. loads `Pro-L 2` on the parent track;
5. selects the newly created parent track.

### Requirement

REAPER's FX Browser must be able to resolve the plugin using:

```text
Pro-L 2
```

If your installed plugin uses a different display name, edit the line near the top of the script:

```lua
local fx_name = "Pro-L 2"
```

### Typical use

Quickly package layered game-audio tracks into a bus and insert a limiter for peak control.

---

## 8. Split Selected Items to New Tracks

Current version: **1.0**

File:

```text
psy_Split Selected Items to New Tracks_拆分选中素材到新轨道.lua
```

### What it does

Moves each selected media item onto its own newly created track while:

- preserving the original timeline position;
- creating the new track below the source track;
- naming the new track from the item's active Take name.

### Typical use

When many independent SFX clips sit on one track, use this script to explode them vertically, then run Sort Tracks by Earliest Item Position to organize the new tracks.

These two scripts work particularly well as a pair for sound-design session cleanup.

---

## 9. Reverse Selected Items in Place

Current version: **1.0**

File:

```text
psy_Reverse Selected Items in Place_原位反转选中素材.lua
```

### What it does

Reverses the selected items and keeps the reversed result as the only remaining Take.

Internally it runs:

1. `Item: Reverse items to new take`;
2. `Take: Crop to active take`.

The end result behaves like an in-place reverse without retaining the original unreversed Take.

### Note

This is a relatively destructive Take-cleanup workflow, but the entire operation can be undone with a single `Ctrl+Z`.

---

# Suggested Shortcut Workflow

| Script | Suggested access |
|---|---|
| Create Folder Region and Render Matrix | Frequently used shortcut |
| Sort Tracks by Earliest Item Position | Frequently used shortcut |
| Split Selected Items to New Tracks | Shortcut |
| Remove Gaps Between Selected Items | Shortcut |
| Reverse Selected Items in Place | Shortcut |
| Toggle LUFS-M and Spectrogram | Toolbar button or shortcut |
| Smart Tail Render Panel | Toolbar button |
| Open Render Dialog with Auto Tail | Replace normal Render shortcut |
| Create Folder + Pro-L 2 | Toolbar button or shortcut |

---

# Suggested Combined Workflows

## Multi-item track cleanup

```text
Select multiple items
→ Split Selected Items to New Tracks
→ Sort Tracks by Earliest Item Position
→ Create Folder / Bus
```

## Batch game-audio rendering

```text
Select the items to export
→ Create Folder Region and Render Matrix
→ Configure tail with Smart Tail Render Panel
→ Open Render Dialog with Auto Tail
→ Batch render through Region Render Matrix
```

---

# Dependencies and Compatibility

Most scripts use only native REAPER ReaScript APIs.

Unless explicitly stated otherwise, they do not require:

- SWS Extension;
- js_ReaScriptAPI;
- ReaImGui.

ReaPack is only used for installation and updates. It is not a runtime dependency for these scripts.

---

# Updating

Users who installed the scripts through ReaPack can update them through:

`Extensions → ReaPack → Synchronize packages`

Script version numbers and the ReaPack index are maintained together when features are updated.
