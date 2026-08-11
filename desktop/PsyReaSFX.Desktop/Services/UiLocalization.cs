using System.Collections;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;

namespace PsyReaSFX.Desktop.Services;

/// <summary>
/// Lightweight runtime localization for the standalone shell. User-authored
/// library names, paths and metadata are deliberately never translated.
/// </summary>
public static class UiLocalization
{
    private static readonly (string Zh, string En)[] Pairs =
    [
        ("显示或隐藏导航 · F9", "Show or hide navigation · F9"),
        ("显示或隐藏元数据 · F10", "Show or hide metadata · F10"),
        ("专注模式 · F11", "Focus mode · F11"),
        ("搜索文件名、描述、关键词、分类、路径和逻辑库 · Ctrl+F", "Search filename, description, keywords, category, path and library · Ctrl+F"),
        ("搜索文件名、关键词或描述…   category:impact   library:name   -exclude", "Search filenames, keywords or descriptions…   category:impact   library:name   -exclude"),
        ("清空搜索", "Clear search"), ("自动试听", "Auto preview"), ("增量扫描 · Ctrl+R", "Incremental scan · Ctrl+R"),
        ("使用说明", "User guide"), ("设置", "Settings"),
        ("PsyReaSFX 设置", "PsyReaSFX Settings"),
        ("右键表头选择字段；拖动分隔线调整列宽；Shift+滚轮横向查看", "Right-click headers to choose fields; drag dividers to resize; Shift+wheel to pan horizontally"),
        ("隐藏导航  ‹", "Hide navigation  ‹"), ("隐藏元数据  ›", "Hide metadata  ›"),
        ("SOUNDS", "SOUNDS"), ("LIBRARIES", "LIBRARIES"), ("COLLECTIONS", "COLLECTIONS"),
        ("SAVED SEARCHES", "SAVED SEARCHES"), ("FACETS", "FACETS"), ("WORKFLOW", "WORKFLOW"), ("ACTIVITY", "ACTIVITY"),
        ("素材", "SOUNDS"), ("音效库", "LIBRARIES"), ("集合", "COLLECTIONS"),
        ("保存搜索", "SAVED SEARCHES"), ("筛选", "FACETS"), ("工作流", "WORKFLOW"), ("活动", "ACTIVITY"),
        ("全部素材  ", "All sounds  "), ("收藏  ", "Favorites  "), ("试听历史  ", "Preview history  "),
        ("最近插入", "Recently inserted"),
        ("全部音效库", "All libraries"), ("＋ 新建音效库", "+ New library"), ("管理音效库", "Manage libraries"),
        ("＋ 播放列表", "+ Playlist"), ("＋ 项目素材箱", "+ Project bin"), ("加入已选", "Add selected"), ("移出已选", "Remove selected"),
        ("＋ 保存当前", "+ Save current"), ("删除", "Delete"),
        ("分类", "Category"), ("格式", "Format"), ("声道", "Channels"), ("清除 Facet", "Clear facets"),
        ("全部分类", "All categories"), ("全部格式", "All formats"), ("全部声道", "All channels"),
        ("全部状态", "All statuses"), ("候选", "Candidate"), ("已采用", "Approved"), ("已排除", "Rejected"), ("未标记", "Unmarked"),
        ("选择一个素材查看波形并试听", "Select an asset to view its waveform and audition controls"),
        ("播放 / 暂停 · Space", "Play / pause · Space"), ("停止", "Stop"), ("收藏 · F", "Favorite · F"), ("更多操作", "More actions"),
        ("清除本次试听高亮", "Clear current audition highlights"),
        ("清除本次已试听高亮", "Clear current audition highlights"),
        ("拖出选区", "Drag selection out"),
        ("已保存 Region", "Saved Regions"),
        ("循环当前选区 · L", "Loop selection · L"), ("反向试听 · R", "Reverse audition · R"),
        ("改变速度时保持音高", "Preserve pitch while changing speed"), ("声道监听", "Channel audition"),
        ("清除选区并重置缩放", "Clear selection and reset zoom"), ("滚轮缩放 · Shift+滚轮平移", "Wheel to zoom · Shift+wheel to pan"),
        ("暂无封面", "No artwork"), ("选择一个素材", "Select an asset"), ("选择封面", "Choose artwork"), ("自动查找封面", "Auto-detect artwork"),
        ("标记素材 · M", "Mark asset · M"), ("保存元数据", "Save metadata"), ("撤销元数据", "Undo metadata"),
        ("从文件名解析 UCS", "Parse UCS from filename"), ("导入 CSV", "Import CSV"), ("导出 CSV", "Export CSV"),
        ("★ 收藏 / Favorite", "★ Favorite"), ("在资源管理器中显示", "Show in File Explorer"),
        ("常规", "General"), ("外观", "Appearance"), ("波形与性能", "Waveforms & performance"), ("传输", "Transfer"), ("维护", "Maintenance"), ("关于", "About"),
        ("设置中心", "Settings"), ("语言、面板与插入", "Language, panels and insertion"),
        ("波形精度与性能", "Waveform resolution and performance"), ("环境、缓存与重建", "Environment, cache and rebuild"),
        ("处理、命名与导出", "Processing, naming and export"),
        ("版本、版权与项目主页", "Version, copyright and project page"),
        ("界面语言", "Interface language"), ("简体中文", "简体中文"),
        ("保存后主界面立即切换；重新启动时保持所选语言。", "The main window updates after saving and remembers the language on restart."),
        ("只显示当前桌面版已经实际接通的选项。", "Only options that are connected in this desktop build are shown."),
        ("试听", "Audition"), ("选择素材后自动试听", "Automatically preview selected assets"),
        ("空格键行为", "Space key behavior"), ("暂停 / 继续", "Pause / resume"), ("从选区起点重新播放", "Restart from selection start"),
        ("播放按钮始终使用标准暂停 / 继续逻辑；此选项只影响 Space。", "The play button always uses normal pause/resume behavior; this option only affects Space."),
        ("主题与颜色", "Theme & colors"), ("黑暗模式", "Dark mode"), ("传统模式", "Classic mode"),
        ("框架底色", "Frame color"), ("面板底色", "Panel color"), ("表头底色", "Header color"),
        ("分隔线", "Dividers"), ("主要文字", "Primary text"), ("次要文字", "Muted text"),
        ("强调色", "Accent color"), ("选中行", "Selected row"), ("已播放文字", "Played text"),
        ("普通波形", "Normal waveform"), ("选中波形", "Selected waveform"), ("已播放波形", "Played waveform"),
        ("已标记波形", "Marked waveform"), ("选区颜色", "Selection color"), ("播放指针", "Playhead"), ("Region 颜色", "Region color"),
        ("已播放素材使用独立波形颜色", "Use a separate waveform color for played assets"),
        ("恢复当前主题默认颜色", "Restore current theme colors"),
        ("点击色块打开系统色盘；修改会立即预览，保存后持久保留。", "Click a swatch to open the system color picker. Changes preview immediately and persist after saving."),
        ("列表连续移动时会短暂等待，避免为经过的每一行反复打开文件。", "A short delay prevents opening every row while moving quickly through the list."),
        ("启动布局", "Startup layout"), ("启动时显示左侧导航", "Show navigation on startup"), ("启动时显示右侧元数据", "Show metadata on startup"),
        ("列表波形精度", "Inline waveform resolution"), ("256 点（更快）", "256 points (faster)"), ("512 点（更细）", "512 points (finer)"),
        ("大波形精度", "Detail waveform resolution"), ("2048 点", "2048 points"), ("4096 点", "4096 points"),
        ("精度越高，首次读取所需的磁盘与处理时间越多。", "Higher resolutions require more disk access and processing on first load."),
        ("瞬态 Region 建议", "Transient Region suggestions"), ("阈值 (dBFS)", "Threshold (dBFS)"),
        ("平滑时间 (ms)", "Smoothing (ms)"), ("最小间隔 (ms)", "Minimum interval (ms)"),
        ("最大 Region 数", "Maximum Regions"), ("Region 前置 (ms)", "Region pre-roll (ms)"),
        ("Region 后置 (ms)", "Region post-roll (ms)"), ("检测时替换已有瞬态建议", "Replace existing transient suggestions when detecting"),
        ("响度统计", "Loudness statistics"), ("显示当前素材响度统计", "Show loudness statistics for the current asset"),
        ("试听时匹配响度", "Match loudness while auditioning"), ("目标 LUFS-I", "Target LUFS-I"), ("响度匹配试听", "Loudness-matched audition"),
        ("性能说明", "Performance"),
        ("PsyReaSFX 只为屏幕上可见的结果读取列表波形。正在试听时会优先保证音频与播放指针，不让后台波形任务抢占交互。", "PsyReaSFX loads inline waveforms only for visible results. During audition, audio and the playhead take priority over background waveform work."),
        ("桌面数据库", "Desktop database"), ("打开数据目录", "Open data directory"), ("诊断日志", "Diagnostic log"), ("打开日志目录", "Open log directory"),
        ("数据、设置与诊断入口。", "Data, settings and diagnostic entry points."),
        ("目录监视、任务恢复、备份与缓存健康检查。", "Folder monitoring, task recovery, backups and cache health checks."),
        ("Watch Folder", "Watch folders"),
        ("自动监视已启用的音效库路径", "Automatically monitor enabled library paths"),
        ("变更合并等待（秒）", "Change debounce (seconds)"),
        ("启动时恢复上次中断的增量扫描", "Resume an interrupted incremental scan at startup"),
        ("重试失败任务", "Retry failed tasks"), ("清除恢复记录", "Clear recovery records"),
        ("数据库备份与恢复", "Catalog backup and restore"),
        ("每天自动创建一份数据库备份", "Create one catalog backup per day automatically"),
        ("保留份数", "Backups to retain"),
        ("立即备份", "Back up now"), ("打开备份目录", "Open backup folder"),
        ("下次启动恢复最新备份", "Restore latest backup on next launch"),
        ("缓存完整性", "Cache integrity"),
        ("波形缓存目录", "Waveform cache directory"),
        ("列表与高精度波形缓存存放在此目录。更改目录时可以迁移已有缓存，不会移动源音频。", "Inline and high-resolution waveform caches are stored here. Existing caches can be migrated without moving source audio."),
        ("可将现有缓存迁移到自定义目录，也可以只切换到新的空目录。源音频不会移动。", "Move existing waveform caches to a custom directory, or switch to a new empty directory. Source audio is never moved."),
        ("当前目录", "Current directory"),
        ("更改缓存目录…", "Change cache directory…"),
        ("打开缓存目录", "Open cache directory"),
        ("恢复默认目录", "Restore default directory"),
        ("尚未更改缓存目录。", "The cache directory has not been changed."),
        ("验证现有 RWF 波形缓存；损坏文件会被安全移除并在需要时自动重建。", "Validate existing RWF waveform caches. Damaged files are safely removed and rebuilt when needed."),
        ("检查并修复波形缓存", "Check and repair waveform cache"),
        ("Transfer 导出", "Transfer"), ("输出 / Output", "Output"),
        ("Transfer 使用独立目录且不会修改源素材。", "Transfer writes to an independent output directory and never modifies source media."),
        ("更改…", "Change…"), ("打开目录", "Open folder"), ("命名模板", "Naming template"),
        ("文件名转为小写 / Lowercase filename", "Lowercase filename"),
        ("格式与范围 / Format and scope", "Format and scope"), ("导出范围", "Export scope"),
        ("当前选区", "Current selection"), ("完整文件", "Full file"), ("输出格式", "Output format"),
        ("采样率", "Sample rate"), ("跟随源文件", "Source rate"),
        ("声道", "Channels"), ("跟随源声道", "Source channels"), ("单声道", "Mono"), ("立体声", "Stereo"),
        ("尽可能保留源文件元数据和旁车文件", "Preserve source metadata and sidecar files when possible"),
        ("处理 / Processing", "Processing"),
        ("当前 Pitch、Rate、Gain、Reverse 与 Preserve Pitch 会写入导出文件。", "Current Pitch, Rate, Gain, Reverse and Preserve Pitch settings are rendered into the exported file."),
        ("淡入 (ms)", "Fade in (ms)"), ("淡出 (ms)", "Fade out (ms)"), ("标准化目标", "Normalize target"),
        ("标准化", "Normalize"), ("关闭", "Off"), ("抖动 / Dither", "Dither"), ("噪声整形 / Noise shaping", "Noise shaping"),
        ("智能尾音 / Smart tail", "Smart tail"), ("选区后继续保留源文件中的衰减尾音", "Keep decaying source-file audio after the selection"),
        ("最大尾音 (ms)", "Maximum tail (ms)"), ("静音保持 (ms)", "Silence hold (ms)"),
        ("独立版只能延长源文件本身的选区，不包含 REAPER 工程发送轨或 Master FX。", "The standalone build can extend only audio that exists in the source file; REAPER sends and Master FX are not available."),
        ("批量变体 / Batch variants", "Batch variants"), ("启用 Pitch × Rate × Gain 组合", "Enable Pitch × Rate × Gain combinations"),
        ("Pitch（逗号分隔）", "Pitch (comma separated)"), ("同时生成 Reverse 版本", "Also generate reversed variants"),
        ("模板未含变体字段时自动追加安全后缀", "Append a safe suffix when the naming template has no variant field"),
        ("每项最多 16 个值、每个素材最多 128 个变体、单次最多 4096 个任务。", "Up to 16 values per field, 128 variants per asset and 4,096 jobs per run."),
        ("完成行为 / Completion", "Completion"), ("重名策略", "Name collision"),
        ("自动递增", "Increment"), ("跳过已有文件", "Skip existing"), ("允许覆盖", "Allow overwrite"),
        ("导出完成后打开输出目录", "Open the output folder after export"),
        ("定位最新输出", "Reveal latest output"), ("打开任务报告", "Open task report"),
        ("取消任务", "Cancel job"), ("导出当前素材", "Export current asset"), ("导出所选素材", "Export selected assets"),
        ("输出目录", "Output directory"), ("打开 Transfer 面板", "Open Transfer panel"),
        ("完整的 Transfer 参数位于独立面板，可从主界面或 Ctrl+T 打开。设置会自动保存。", "All Transfer options live in the dedicated panel. Open it from the main toolbar or with Ctrl+T; settings are saved automatically."),
        ("当前输出目录", "Current output directory"),
        ("PsyReaSFX 帮助中心", "PsyReaSFX Help Center"),
        ("帮助中心", "Help Center"), ("快速使用说明", "Quick guide"),
        ("快速开始", "Quick start"), ("搜索与筛选", "Search & filters"),
        ("试听与波形", "Audition & waveform"), ("选择与整理", "Selection & organization"),
        ("快捷键", "Shortcuts"), ("从音效库到工程的核心流程。", "The core workflow from sound library to project."),
        ("01  建立音效库", "01  Build a library"),
        ("在左侧新建逻辑音效库，再为它添加一个或多个实体文件夹。PsyReaSFX 会增量建立索引，并复用波形缓存。", "Create a logical library in the navigation panel, then add one or more source folders. PsyReaSFX indexes them incrementally and reuses waveform caches."),
        ("02  查找与试听", "02  Find and audition"),
        ("输入关键词或字段筛选；单击列表波形可从对应位置试听，选中结果后可在大波形中精确定位和建立选区。", "Enter keywords or field filters. Click an inline waveform to audition from that point, then use the detail waveform for precise positioning and range selection."),
        ("03  整理与交付", "03  Organize and deliver"),
        ("使用收藏、工作流状态、播放列表和 Region 整理候选素材；拖动结果或选区即可交给 REAPER 与其他支持文件拖放的软件。", "Use favorites, workflow status, playlists and Regions to organize candidates. Drag results or a selected range to REAPER or another application that accepts file drops."),
        ("普通关键词会匹配文件名、描述和关键词；字段语法可缩小范围。", "Plain terms match filenames, descriptions and keywords. Field syntax narrows the result set."),
        ("常用字段", "Common fields"), ("逻辑音效库", "Logical library"), ("工作流状态", "Workflow status"),
        ("实体路径", "Source path"), ("声道数", "Channel count"), ("排除关键词", "Exclude a term"),
        ("组合示例", "Combined example"),
        ("查找 Boom 库中的金属 Impact，并排除包含 long 的结果。", "Find metal impacts in the Boom library and exclude results containing long."),
        ("列表用于快速筛选，大波形用于精确试听、声道检查和选区操作。", "Use the list for fast browsing and the detail waveform for precise audition, channel inspection and range work."),
        ("基础操作", "Core controls"),
        ("• 单击列表波形：从点击位置试听", "• Click an inline waveform: audition from that point"),
        ("• 单击大波形：定位播放头；拖动：建立选区", "• Click the detail waveform: position the playhead; drag: create a range"),
        ("• 滚轮：缩放；Shift + 滚轮：水平平移", "• Wheel: zoom; Shift + wheel: pan horizontally"),
        ("• 右键拖动：连续擦播", "• Right-drag: continuous scrub"),
        ("• 多声道素材：展开声道栏，单独监听 CH 1…CH N", "• Multichannel assets: expand the channel strip and isolate CH 1…CH N"),
        ("选区交付", "Range delivery"),
        ("建立有效选区后，波形内会出现“拖出选区”胶囊。按住它拖向 REAPER，即可交付精确选区，而不会修改源文件。", "After creating a valid range, a Drag selection out capsule appears inside the waveform. Drag it to REAPER to deliver the exact range without modifying the source file."),
        ("批量选择遵循 Windows 的标准交互。", "Batch selection follows standard Windows interaction."),
        ("结果选择", "Result selection"),
        ("Ctrl + 单击：追加或取消单个结果", "Ctrl + click: add or remove one result"),
        ("Shift + 单击：连续范围选择", "Shift + click: select a contiguous range"),
        ("Ctrl + A：全选当前筛选结果", "Ctrl + A: select all current filtered results"),
        ("资料管理", "Asset organization"),
        ("右键逻辑库可添加和管理实体路径；右键素材可设置工作流状态、标记、收藏或定位源文件。元数据编辑只写入 PsyReaSFX 数据库，不改写源音频。", "Right-click a logical library to add or manage source folders. Right-click an asset to set workflow status, mark, favorite or reveal the source. Metadata edits are stored only in the PsyReaSFX database and never rewrite source audio."),
        ("高频命令在浏览时始终可用。", "Frequent commands remain available while browsing."),
        ("播放 / 暂停", "Play / pause"), ("聚焦搜索", "Focus search"), ("增量扫描", "Incremental scan"),
        ("打开 Transfer", "Open Transfer"), ("导航面板", "Navigation panel"), ("元数据面板", "Metadata panel"),
        ("专注模式", "Focus mode"), ("关闭帮助", "Close help"),
        ("提示：鼠标悬停主界面图标可查看具体功能。", "Tip: hover over a main-window icon to see its function."),
        ("关闭", "Close"),
        ("取消", "Cancel"), ("保存并关闭", "Save and close"),
        ("Waveform", "Waveform"), ("Filename", "Filename"), ("Keywords / Description", "Keywords / Description"),
        ("Artwork", "Artwork"), ("Duration", "Duration"), ("Status", "Status"), ("Marked", "Marked"),
        ("Library", "Library"), ("Category", "Category"), ("SubCategory", "SubCategory"), ("Format", "Format")
    ];

    public static bool IsEnglish(string? language) => string.Equals(language, "en-US", StringComparison.OrdinalIgnoreCase);
    public static string Text(string zh, string en, string? language) => IsEnglish(language) ? en : zh;

    public static void Apply(DependencyObject root, string? language)
    {
        var english = IsEnglish(language);
        Walk(root, english, new HashSet<DependencyObject>());
    }

    private static void Walk(DependencyObject value, bool english, HashSet<DependencyObject> visited)
    {
        if (!visited.Add(value)) return;
        switch (value)
        {
            case Window window:
                window.Title = Translate(window.Title, english);
                break;
            case HeaderedContentControl headered when headered.Header is string header:
                headered.Header = Translate(header, english);
                break;
            case ContentControl content when content.Content is string text:
                content.Content = Translate(text, english);
                break;
            case TextBlock block:
                if (!string.IsNullOrEmpty(block.Text)) block.Text = Translate(block.Text, english);
                foreach (var inline in block.Inlines.OfType<Run>().ToArray()) inline.Text = Translate(inline.Text, english);
                break;
        }
        if (value is FrameworkElement element && element.ToolTip is string tooltip)
            element.ToolTip = Translate(tooltip, english);
        if (value is DataGrid grid)
            foreach (var column in grid.Columns)
                if (column.Header is string header) column.Header = Translate(header, english);
        // Translating a Run can invalidate WPF's RangeContentEnumerator. Take
        // a snapshot before recursing so runtime language switching never
        // mutates the collection currently being enumerated.
        foreach (var child in LogicalTreeHelper.GetChildren(value).OfType<DependencyObject>().ToArray()) Walk(child, english, visited);
    }

    private static string Translate(string value, bool english)
    {
        if (!english)
        {
            value = value switch
            {
                "SOUNDS" => "素材",
                "LIBRARIES" => "音效库",
                "COLLECTIONS" => "集合",
                "SAVED SEARCHES" => "保存搜索",
                "FACETS" => "筛选",
                "WORKFLOW" => "工作流",
                "ACTIVITY" => "活动",
                _ => value
            };
        }
        foreach (var pair in Pairs)
        {
            if (string.Equals(value, pair.Zh, StringComparison.Ordinal) || string.Equals(value, pair.En, StringComparison.Ordinal))
                return english ? pair.En : pair.Zh;
        }
        return value;
    }
}
