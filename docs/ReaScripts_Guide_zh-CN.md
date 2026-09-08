# Psysia ReaScripts 使用手册

> 一组面向 REAPER 音效编辑、轨道整理与渲染工作流的实用脚本。
>
> 作者：Psysia  
> 仓库：Psysia/PsyReaSFX

[English Guide](./ReaScripts_Guide.md)

---

## 安装

### 使用 ReaPack 安装

在 REAPER 中打开：

`Extensions → ReaPack → Import repositories...`

添加仓库索引：

```text
https://raw.githubusercontent.com/Psysia/PsyReaSFX/main/index.xml
```

随后执行：

`Extensions → ReaPack → Synchronize packages`

在 ReaPack 中搜索 `Psysia`、`psy_` 或脚本名称即可安装。

### 手动安装

脚本文件位于：

```text
Scripts/Psysia/
```

将 `.lua` 文件复制到 REAPER Resource Path 下的 `Scripts` 文件夹，然后在：

`Actions → Show action list → New action → Load ReaScript...`

加载对应脚本即可。

建议为高频脚本绑定快捷键或工具栏按钮。

---

# 当前脚本

## 1. 创建文件夹区域与渲染矩阵

**Create Folder Region and Render Matrix**  
当前版本：**2.4**

文件：

```text
psy_Create Folder Region and Render Matrix_创建文件夹区域与渲染矩阵.lua
```

### 功能

根据当前选中的素材或轨道自动：

1. 计算需要渲染的时间范围；
2. 判断素材所属轨道及其文件夹层级；
3. 创建或更新 Region；
4. 使用合适的父文件夹轨道名称给 Region 命名；
5. 自动写入 Region Render Matrix。

### 文件夹识别规则

- 单个源轨道本身是文件夹轨道：使用该轨道。
- 单个源轨道位于文件夹内：使用它的直接父文件夹。
- 多个源轨道：寻找它们最近的公共父级。
- 多个素材拥有完全相同的时间范围时，也允许创建多个逻辑 Region。
- 只有“时间范围相同 + Render Matrix 目标相同”时才视为同一个 Region。

### 推荐用法

框选一组需要作为同一个音效资产输出的素材，然后运行脚本。

适合：

- 游戏音效分层素材整理；
- 文件夹 Bus 渲染；
- Region Render Matrix 批量导出；
- 多层文件夹工程的自动命名。

### 注意

脚本会修改 Region 和 Region Render Matrix，建议在正式工程中先确认素材选择是否正确。

---

## 2. 按最早素材位置排序轨道

**Sort Tracks by Earliest Item Position**  
当前版本：**1.3**

文件：

```text
psy_Sort Selected Tracks by Earliest Item Position_按最早素材位置排序选中轨道.lua
```

### 功能

按照素材在时间线上的最早出现位置，对相关轨道进行从上到下排序。

### 两种工作模式

#### A. 选中了素材

只要存在选中的 Media Item，素材模式优先。

脚本会：

1. 自动识别这些素材所在的轨道；
2. 同一轨道有多个选中素材时，取其中最早的素材位置；
3. 按该位置对轨道排序。

因此无需额外手动选中轨道。

#### B. 没有选中素材，但选中了轨道

脚本会读取每条选中轨道上的全部素材，并以该轨道最早的素材位置作为排序依据。

### 额外规则

- 两条轨道的最早位置相同时，保持原来的上下顺序。
- 非连续选择的轨道会尽量保留原来的目标槽位。
- 排序时保护 Folder ending 关系。
- 执行完成后恢复原来的轨道选择状态。

### 典型用途

把多个技能、动作或 UI 声音的分层素材纵向摆放后，框选需要整理的素材，一键让轨道顺序与声音进入时间一致。

---

## 3. 打开渲染窗口并应用自动尾音

**Open Render Dialog with Auto Tail**  
当前版本：**1.0**

文件：

```text
psy_Open Render Dialog with Auto Tail_打开渲染对话框并应用自动尾音.lua
```

### 功能

用于替代普通的：

`File → Render`

当智能尾音功能处于启用状态时，脚本会先把自动尾音参数写入当前工程，再打开 REAPER 原生 Render 窗口。

主要处理：

- 最大尾音长度；
- Trim ending silence；
- 尾音裁切阈值；
- 尾部安全留白；
- 不同 Render Bounds 对应的 Tail Flag。

### 默认参数

若没有保存过用户设置，默认使用：

- 最大尾音：12 秒；
- 裁切阈值：-60 dBFS；
- 安全留白：80 ms。

### 推荐用法

如果你已经在使用“智能尾音渲染面板”配置尾音参数，可以把这个脚本绑定到原来的 Render 快捷键，用它作为日常打开渲染窗口的入口。

---

## 4. 智能尾音渲染面板

**Smart Tail Render Panel**  
当前版本：**1.1**

文件：

```text
psy_Smart Tail Render Panel_智能尾音渲染面板.lua
```

### 功能

通过 REAPER 原生 Render Tail 与 Trim ending silence 功能，减少混响、Delay、长尾素材在批量渲染时被时间范围硬切断的问题。

工作方式：

```text
原始渲染范围
→ 额外增加最大尾音时间
→ 按 dBFS 阈值裁掉结尾静音
→ 添加少量安全留白
```

### 可调整参数

- **Threshold / 阈值**：决定何时认为尾音已经足够安静；
- **Max Tail / 最大尾音**：允许额外渲染的最大时间；
- **Safety / 安全留白**：裁切点后额外保留的时间；
- **Trim**：是否启用尾部静音裁切；
- **Pad**：是否启用尾部安全留白；
- **Scope**：决定 Tail 设置作用于当前范围、Region 或全部支持的范围。

### 默认值

- Threshold：-60 dBFS；
- Max Tail：10 秒；
- Safety：200 ms。

### 重要说明

该脚本只解决“渲染时间范围截断”的问题，不会自动改变路由。

如果混响或 Delay 位于独立 Return 轨道，必须保证它最终回到被渲染的 Bus，或者该 Return 本身包含在渲染源中，否则尾音仍可能无法进入最终文件。

脚本不依赖 SWS、ReaPack 或 ReaImGui。

---

## 5. 移除选中素材间隙

**Remove Gaps Between Selected Items**  
当前版本：**1.0**

文件：

```text
psy_Remove Gaps Between Selected Items_移除选中素材间隙.lua
```

### 功能

把多个选中的 Media Item 首尾相接排列，移除它们之间的空隙。

脚本会让后一个素材的起点移动到前一个素材的终点：

```text
Item A    Item B       Item C
[-----]   [----]       [---]

↓

[-----][----][---]
```

### 注意

脚本会直接改变素材在时间线上的位置。

建议用于已经确认顺序的素材集合，并通过 `Ctrl+Z` 撤销误操作。

---

## 6. 切换 LUFS-M 与频谱图

**Toggle LUFS-M and Spectrogram**  
当前版本：**1.0**

文件：

```text
psy_Toggle LUFS-M and Spectrogram_切换LUFS-M与频谱图.lua
```

### 功能

一键在以下两种 Peaks 显示模式之间切换：

1. Spectral Peaks + Momentary Loudness（LUFS-M）；
2. Spectrogram。

脚本会自动在 REAPER Action List 中寻找对应动作，而不是写死当前机器上的 Command ID。

因此恢复快捷键配置或动作编号变化后，兼容性更好。

### 注意

脚本需要当前 REAPER 版本支持动作枚举 API。

如果脚本提示找不到动作，请检查 Action List 中是否仍能找到对应英文动作名称。

---

## 7. 从选中轨道创建文件夹并挂载 Pro-L 2

**Create Folder from Selected Tracks with Pro-L 2**  
当前版本：**1.0**

文件：

```text
psy_Create Folder from Selected Tracks with Pro-L 2_从选中轨道创建文件夹并挂载Pro-L 2.lua
```

### 功能

选择一组轨道后运行脚本，会：

1. 在第一条选中轨道上方创建新的父轨道；
2. 把选中轨道包进该 Folder；
3. 将父轨道命名为 `Folder Bus`；
4. 在父轨道上加载 `Pro-L 2`；
5. 最后选中新建的父轨道。

### 前提

你的 REAPER FX Browser 必须能够通过名称：

```text
Pro-L 2
```

找到 FabFilter Pro-L 2。

如果你的插件显示名称不同，可以修改脚本顶部的：

```lua
local fx_name = "Pro-L 2"
```

### 适合

快速把多层游戏音效轨道打包进一个 Bus，并立即挂载 Limiter 做峰值控制。

---

## 8. 拆分选中素材到新轨道

**Split Selected Items to New Tracks**  
当前版本：**1.0**

文件：

```text
psy_Split Selected Items to New Tracks_拆分选中素材到新轨道.lua
```

### 功能

将每一个选中的 Media Item 移动到独立的新轨道，同时：

- 保持素材原来的时间位置；
- 在源轨道下方创建新轨道；
- 使用素材当前 Active Take 的名称自动命名新轨道。

### 典型用途

一条轨道上摆了大量单独的音效素材时，可以批量拆成纵向轨道，随后再使用“按最早素材位置排序轨道”进行整理。

这两个脚本组合起来尤其适合音效设计工程整理。

---

## 9. 原位反转选中素材

**Reverse Selected Items in Place**  
当前版本：**1.0**

文件：

```text
psy_Reverse Selected Items in Place_原位反转选中素材.lua
```

### 功能

对选中的素材执行反转，并把反转结果保留为当前唯一 Take。

内部流程：

1. `Item: Reverse items to new take`；
2. `Take: Crop to active take`。

最终效果类似“直接把素材原位反转”，不会保留原始未反转 Take。

### 注意

这是破坏性较强的 Take 整理方式，但整个操作可以通过一次 `Ctrl+Z` 撤销。

---

# 推荐快捷键工作流

以下只是建议，可按个人习惯调整：

| 脚本 | 推荐使用方式 |
|---|---|
| 创建文件夹区域与渲染矩阵 | 高频快捷键 |
| 按最早素材位置排序轨道 | 高频快捷键 |
| 拆分选中素材到新轨道 | 快捷键 |
| 移除选中素材间隙 | 快捷键 |
| 原位反转选中素材 | 快捷键 |
| LUFS-M / 频谱图切换 | 工具栏按钮或快捷键 |
| 智能尾音渲染面板 | 工具栏按钮 |
| 打开渲染窗口并应用自动尾音 | 替代普通 Render 快捷键 |
| 创建 Folder + Pro-L 2 | 工具栏按钮或快捷键 |

---

# 建议组合工作流

## 多素材轨道整理

```text
框选多个素材
→ 拆分选中素材到新轨道
→ 按最早素材位置排序轨道
→ 创建 Folder / Bus
```

## 游戏音效批量渲染

```text
框选需要输出的素材
→ 创建文件夹区域与渲染矩阵
→ 智能尾音渲染面板设置 Tail
→ 打开渲染窗口并应用自动尾音
→ Region Render Matrix 批量输出
```

---

# 依赖与兼容性

大部分脚本仅使用 REAPER 原生 ReaScript API。

除非脚本说明中特别指出，否则不要求：

- SWS Extension；
- js_ReaScriptAPI；
- ReaImGui。

ReaPack 仅用于安装与更新，不是脚本运行时依赖。

---

# 更新

使用 ReaPack 安装的用户可通过：

`Extensions → ReaPack → Synchronize packages`

获取新版本。

脚本的版本号和 ReaPack 索引会随功能更新同步维护。
