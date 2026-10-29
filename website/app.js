const REPOSITORY = "Psysia/PsyReaSFX";
const REAPACK_URL = "https://github.com/Psysia/PsyReaSFX/raw/main/index.xml";
const STABLE_FALLBACK = {
  version: "0.9.0",
  url: "https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.0"
};
const NEURAL_FALLBACK_URL = "https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip";
let neuralDownloadUrl = NEURAL_FALLBACK_URL;

const messages = {
  en: {
    licenseSummary: "Free for personal and commercial audio/game production. Republishing, redistribution, software resale and using protected project materials to train/distill AI or generate copies require permission. Your creative outputs are unaffected; third-party licenses remain in force. <a href=\"https://github.com/Psysia/PsyReaSFX/blob/main/LICENSE\">Read the license ↗</a>",
    neuralOrigin: "EfficientAT’s AudioSet-trained mn04_as model converts audio into learned features; HNSW finds nearby sounds and acoustic features refine the results. Everything runs locally. Thanks to <a href=\"https://github.com/fschmid56/EfficientAT\">EfficientAT</a> / <a href=\"https://github.com/fschmid56/EfficientAT_HEAR\">EfficientAT_HEAR</a> (MIT license) and Google’s <a href=\"https://research.google.com/audioset/\">AudioSet</a> project. This audio-similarity engine is separate from AI text search.",
    skip: "Skip to content",
    homeLabel: "PsyReaSFX home",
    primaryNavLabel: "Primary navigation",
    languageLabel: "Switch language",
    githubLabel: "View PsyReaSFX on GitHub",
    projectHome: "GitHub project ↗",
    projectHomeHint: " — Full README, source code and project documentation.",
    projectInstallHint: " — Visit the repository for the full installation notes and project information.",
    pageTitle: "PsyReaSFX — Sound Assets Organized",
    pageDescription: "A high-performance REAPER sound library browser with UCS classification, waveform audition, audio-content similarity and delivery tools.",
    navProduct: "Product",
    navStatus: "Releases",
    navWorkflow: "Workflow",
    navInstall: "Install",
    navDocs: "Docs",
    stableChannelShort: "Stable",
    builtFor: "Built for REAPER",
    heroTitle: "Your sound library,<br><span>finally in flow.</span>",
    heroLead: "Browse, organize, audition and deliver large sound libraries without leaving REAPER.",
    installReapack: "Install with ReaPack",
    downloadStable: "Download Stable",
    viewPreview: "What’s new in 0.9 ↓",
    freeUpdate: "One repository · Automatic updates",
    inlineWaveforms: "Inline waveforms",
    visibleFirst: "Visible-first caching",
    nonDestructive: "Non-destructive",
    sourceSafe: "Source media stays untouched",
    insideReaper: "Inside REAPER",
    oneWorkspace: "One dockable workspace",
    largeLibraries: "Large libraries",
    boundedWork: "Bounded background work",
    waveformFirst: "Waveform first",
    seekSelect: "Seek, select and deliver",
    bilingual: "Bilingual",
    englishChinese: "English and Simplified Chinese",
    desktopPreviewLabel: "DESKTOP COMPANION · ALPHA 8",
    desktopPreviewTitle: "Browse before you open the project.",
    desktopPreviewText: "A standalone Windows x64 companion for logical libraries, fast search, waveforms, preview, Artwork, favorites and file drag into REAPER.",
    releaseKicker: "0.9 IS NOW STABLE",
    releaseHeading: "The complete 0.9 workspace, now Stable.",
    stableChannel: "Stable channel",
    stableSummary: "The default ReaPack release for everyday production work.",
    getStable: "Get Stable ↗",
    previewChannel: "New in 0.9",
    previewSummary: "UCS classification, acoustic/neural similarity, independent AI semantic search and named API presets, scalable fonts, folder navigation, browsing tabs with snapshots, Watch Folder controls and precise publisher-product browsing. All Beta 8.7 features are included in Stable.",
    getPreview: "Read 0.9 release notes ↗",
    neuralAddon: "Download complete neural ZIP · Windows x64 ↗",
    neuralInstallNote: "Normal ReaPack synchronization now updates PsyReaSFX.lua to 0.9.0 Stable. Neural retrieval requires the separate <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">PsyReaSFX Neural Similarity package</a>; neither package requires pre-release opt-in. Versions retains 0.9.0, 0.8.5 and 0.7.23 Stable.",
    downloadDesktop: "Download Desktop Alpha 8",
    desktopGuide: "Desktop guide ↗",
    completeLoop: "THE COMPLETE SOUND-LIBRARY LOOP",
    fourMoves: "Four moves. One workspace.",
    fourMovesLead: "Keep discovery, decisions and delivery connected instead of rebuilding context across separate tools.",
    discover: "Discover",
    discoverText: "Search filenames and metadata, browse indexed folders, then audition from any point in an inline waveform.",
    organize: "Organize",
    organizeText: "Unify multiple folders as one logical library, then use Artwork, metadata, collections and workflow states.",
    audition: "Audition",
    auditionText: "Inspect channel lanes, select and loop a range, tune Pitch, Rate and Gain, and compare loudness.",
    deliver: "Deliver",
    deliverText: "Insert or drag into REAPER, preserve BWF placement, or render processed variants with Transfer.",
    librariesKicker: "LIBRARIES THAT MATCH REAL STORAGE",
    oneNameManyFolders: "One library name.<br>As many source folders as you need.",
    oneNameText: "Create the logical library first, then attach locations across drives over time. Each source keeps its own path, online state and Artwork.",
    folderDrag: "Drag folders directly from Explorer",
    indexedHierarchy: "Browse the indexed folder hierarchy without rescanning",
    sourceArtwork: "Keep Artwork assigned to the correct physical source",
    waveformKicker: "FROM WAVEFORM TO TIMELINE",
    hearItPlaceIt: "Hear it. Shape it.<br>Place it.",
    hearItText: "Click an inline waveform to start at that exact moment. Build a precise range in the detailed preview, audition it, then drag the selection into the REAPER arrange view.",
    channelLanes: "Mono, stereo and multichannel lanes",
    regionsTransient: "Regions and transient suggestions",
    loudnessStats: "LUFS and True Peak statistics",
    findKicker: "FIND BY STRUCTURE AND SOUND",
    findTitle: "Search the catalog.<br>Then search the audio itself.",
    findText: "Use separate tabs for different libraries and queries. Ctrl+N creates, Ctrl+Shift+N duplicates, Ctrl+W closes and Ctrl+Tab switches. Completed AI/similarity results stay in the session; switching does not call the API again.",
    ucsNavigation: "Browse Category, SubCategory and CatID without moving source files",
    aiSemanticSearch: "Use DeepSeek or an OpenAI-compatible API once to expand a natural-language request, then rank matching metadata locally",
    similarSearch: "Local neural recall across common sample rates, bit depths and formats; <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">neural package required</a>, with safe acoustic fallback",
    spectralPeaks: "Inspect on-demand spectral peaks in the detailed waveform",
    similarityDetails: "Read the similarity architecture ↗",
    aiSemanticDetails: "Read the AI semantic-search architecture ↗",
    deliverWithoutLosing: "Deliver without losing the thread.",
    transferLead: "Turn the full source, a waveform selection or a controlled batch of variants into new files with repeatable settings.",
    smartTail: "Smart source tail",
    batchVariants: "Batch variants",
    designedDepth: "DESIGNED FOR DEPTH",
    dailyFast: "Fast for the daily work.<br>Deep when the project asks.",
    metadataTitle: "Metadata & Artwork",
    metadataText: "Edit a non-destructive database, pin cover art and keep source files safe.",
    searchTitle: "Search & filters",
    searchText: "Combine text, library, UCS fields, marks and workflow states.",
    organizeTitle: "Collections",
    collectionsText: "Build playlists, project bins, favorites and reusable saved searches.",
    performanceTitle: "Large-library performance",
    performanceText: "Visible-first work, bounded queues and persistent waveform caches keep browsing responsive.",
    channelTitle: "Channel-aware preview",
    channelText: "Read mono, stereo and up to eight detailed waveform lanes with focused views.",
    reaperTitle: "REAPER delivery",
    reaperText: "Insert on the current track, a new track, the BWF position or drag the selected range.",
    comparisonKicker: "WHAT CHANGED",
    comparisonHeading: "What does 0.9 Stable add?",
    comparisonLead: "REAPER / Lua editions only, not the Desktop companion. 0.9 includes the earlier Stable feature set; “—” means unavailable in that version.",
    comparisonScroll: "On small screens, swipe the table horizontally to compare all versions.",
    comparisonCaption: "Feature overview · 0.7.23 / 0.8.5 / 0.9.0 Stable",
    comparisonFeature: "Feature",
    comparisonLatest: "Current Stable",
    comparisonDetails: "Detailed version history ↗",
    betaGuideLink: "Update to 0.9 Stable: illustrated guide ↓",
    betaGuideKicker: "UPDATE TO STABLE",
    betaGuideHeading: "Get 0.9.0 through normal ReaPack sync.",
    betaGuideLead: "0.9.0 is now the default Stable release. No pre-release opt-in is required. If an older version is pinned, unpin it first.",
    betaStepOne: "Run Extensions → ReaPack → Synchronize packages, then open Browse packages and search for PsyReaSFX.",
    betaStepTwo: "Right-click the main PsyReaSFX.lua package and uncheck <strong>Pin current version</strong> if an older version is pinned.",
    betaStepThree: "Choose <strong>Install</strong>, or <strong>Versions → 0.9.0</strong> (Stable). The pre-release checkbox is only for future test builds.",
    betaStepFour: "Click <strong>Apply</strong>, or <strong>OK</strong> to confirm installation. Once downloads finish, close the old PsyReaSFX window and rerun it from REAPER's Action List.",
    betaNeuralNote: "<strong>Local neural similarity requires a separate package:</strong> Windows x64 only. <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">Download the complete PsyReaSFX Neural Similarity ZIP</a> (about 42.4 MB, includes model and installers), or install the separate data package through ReaPack. Updating the main script does not install it. <a href=\"#neural-install\">Exact installation steps ↓</a>. Without it, similar-sound search uses the built-in 15-feature acoustic method.",
    betaAiNote: "<strong>AI semantic search:</strong> no <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">neural package</a> required. In Settings, create, save and switch named DeepSeek / OpenAI / compatible API presets, each with an independent key and model. Enter runs normal search; the gold AI button runs semantic search. Audio is not uploaded.",
    betaDataNote: "No mandatory library rebuild. Beta 8.5 or newer neural components and existing caches remain compatible with 0.9.0.",
    betaScreenshotLabel: "View the historical ReaPack menu example at full resolution",
    betaScreenshotCaption: "Historical Beta screenshot showing menu locations. Versions now lists 0.9.0, 0.8.5 and 0.7.23 Stable; older Betas remain on GitHub Releases. Enable pre-releases is not required for 0.9.0.",
    compareIncluded: "Included",
    compareRetained: "Retained",
    compareNone: "—",
    compareAdded: "Added",
    compareRefined: "Retained and refined",
    compareEarly: "Earlier implementation",
    compareHardened: "Hardened",
    compareStartup: "Further startup optimization",
    compareUcsFields: "Basic UCS fields only",
    compareOptIn: "Added; opt-in",
    compare15Features: "Built-in 15-feature acoustic retrieval",
    compareAddon: "<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">Required neural package · Windows x64 ZIP ↗</a>",
    compareApi: "Your API key/model; no <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">neural package</a> needed",
    compareNoDelay: "Added; no fixed intro delay",
    compareFont: "10–24 px font scaling and adaptive waveform columns",
    compareFolders: "Sidebar hierarchy / roots-only and module visibility",
    compareTabs: "Independent search / browsing tabs",
    compareTabsEntry: "Added; + under search / Ctrl+N",
    compareWorkspaceEntry: "Added; Settings → Font & navigation",
    compareCore: "Browse, waveform audition, metadata, collections and Transfer",
    compareRecovery: "Interrupted-scan recovery, retries, backups and cache checks",
    compareMaintenance: "Missing/duplicate checks, source relinking and project usage",
    comparePerformance: "Incremental persistence and frame-budgeted large-library tasks",
    compareUcs: "Official UCS classification, review queue and virtual folders",
    compareSpectral: "Spectral peak coloring",
    compareAcoustic: "Audio-content similar-sound retrieval",
    compareNeural: "EfficientAT local neural similarity",
    compareAi: "AI semantic search: local recall, paging and named API presets",
    compareAnimation: "Branded startup animation and live loading status",
    neuralGuideLink: "Neural package: ReaPack / ZIP instructions ↓",
    neuralInstallKicker: "REQUIRED FOR NEURAL RETRIEVAL",
    neuralInstallHeading: "Get the model, not just the main script.",
    neuralInstallLead: "One Find Similar Sounds entry, two automatic engines: built-in 15-feature acoustic search needs no download; EfficientAT neural retrieval requires <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">PsyReaSFX Neural Similarity</a>. AI semantic search is separate and needs your API settings, not this package.",
    neuralZipDownload: "Download complete neural ZIP ↗",
    neuralDownloadNote: "Windows x64 · 0.9.0 · about 42.4 MB. Includes executable, model and installers. The standalone Release EXE does not include the model. Choose one installation method below.",
    neuralReapackHeading: "Recommended: install inside REAPER",
    neuralReapackOne: "Import the repository URL above, synchronize, then open <strong>Extensions → ReaPack → Browse packages</strong>.",
    neuralReapackTwo: "Search for <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">PsyReaSFX Neural Similarity</a> and select the separate <strong>data package</strong>, not PsyReaSFX.lua.",
    neuralReapackThree: "Choose <strong>Install</strong> or <strong>Versions → 0.9.0</strong> (Stable). Uncheck <strong>Pin current version</strong> if needed; no pre-release opt-in is required.",
    neuralReapackFour: "Click <strong>Apply / OK</strong>, wait for downloads, close the old PsyReaSFX window and rerun it. ReaPack installs and updates the model and executable together.",
    neuralReapackPath: "Installed under <code>&lt;REAPER Resource Path&gt;\\Data\\PsyReaSFX\\neural_similarity\\</code>.",
    neuralManualHeading: "Alternative: install the complete ZIP",
    neuralManualOne: "<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">Download the complete neural ZIP</a> and extract <strong>all files</strong>. Do not run the installer inside the archive.",
    neuralManualTwo: "Double-click <code>Install-NeuralSimilarity.cmd</code>, wait for success, then restart PsyReaSFX.",
    neuralManualThree: "For portable REAPER, open <strong>Options → Show REAPER resource path</strong> to locate its folder, then use the resource-path command in the installer guide.",
    neuralManualPath: "Default manual destination: <code>%APPDATA%\\REAPER\\Scripts\\PsyReaSFX\\neural_similarity\\</code>.",
    neuralInstallerGuide: "Portable / manual installer guide ↗",
    neuralAfterInstall: "No separate Python or .NET runtime is required. Audio stays local, with no converted copies. First use builds a cancelable embedding cache and HNSW index; a missing or failed component automatically falls back to acoustic search.",
    quickStart: "QUICK START",
    installOnce: "Install once.<br>Update inside REAPER.",
    installLead: "Import and synchronize the repository, then install PsyReaSFX 0.9.0 Stable. All Beta 8.7 features are now in the default channel.",
    stepOne: "Open Extensions → ReaPack → Import repositories…",
    stepTwo: "Paste the repository URL below.",
    stepThree: "Synchronize packages, search for PsyReaSFX and install 0.9.0 Stable.",
    copy: "Copy",
    copied: "Copied",
    host: "Host",
    required: "Required",
    recommended: "Recommended",
    downloadLatest: "Download latest Stable",
    learnAndBuild: "LEARN & BUILD",
    docsWhenNeeded: "The detail is there when you need it.",
    userGuide: "User Guide",
    userGuideText: "Complete workflows, controls and troubleshooting.",
    changelog: "Changelog",
    changelogText: "What changed, why it changed and compatibility notes.",
    issueTracker: "Issue tracker",
    issueText: "Report a reproducible problem or follow development.",
    roadmap: "0.9 → 1.0 Roadmap",
    roadmapText: "Follow the feature boundaries, validation gates and neural similarity plan.",
    soundAssetsOrganized: "SOUND ASSETS, ORGANIZED",
    stayInFlow: "Stay in the sound. Stay in the flow.",
    getPsy: "Get PsyReaSFX",
    releases: "Releases"
  },
  zh: {
    licenseSummary: "个人与商业音频／游戏制作均可免费使用。重新发布、二次分发、出售软件，以及用受保护项目材料训练／蒸馏 AI 或生成复制软件，均须获得授权。用户创作成果不受此限制，第三方组件保留各自许可。<a href=\"https://github.com/Psysia/PsyReaSFX/blob/main/LICENSE\">查看完整协议 ↗</a>",
    neuralOrigin: "神经组件用 AudioSet 训练的 mn04_as 模型把声音转换为学习特征，HNSW 查找特征接近的素材，再结合声学特征细化结果；全部在本机运行。感谢 <a href=\"https://github.com/fschmid56/EfficientAT\">EfficientAT</a> / <a href=\"https://github.com/fschmid56/EfficientAT_HEAR\">EfficientAT_HEAR</a>（MIT 许可）及 Google <a href=\"https://research.google.com/audioset/\">AudioSet</a> 项目。这是声音相似检索，与 AI 文本搜索分开。",
    skip: "跳到主要内容",
    homeLabel: "PsyReaSFX 首页",
    primaryNavLabel: "主导航",
    languageLabel: "切换语言",
    githubLabel: "在 GitHub 查看 PsyReaSFX",
    projectHome: "GitHub 项目主页 ↗",
    projectHomeHint: " — 完整 README、源码与项目说明都在这里。",
    projectInstallHint: " — 查看完整安装说明、源码与项目资料。",
    pageTitle: "PsyReaSFX — 让音效素材进入工作流",
    pageDescription: "运行在 REAPER 内的高性能音效素材库，支持 UCS 分类、波形试听、音频内容相似检索与交付工具。",
    navProduct: "产品",
    navStatus: "版本",
    navWorkflow: "工作流",
    navInstall: "安装",
    navDocs: "文档",
    stableChannelShort: "稳定版",
    builtFor: "为 REAPER 打造",
    heroTitle: "让你的音效库，<br><span>真正进入工作流。</span>",
    heroLead: "无需离开 REAPER，即可浏览、整理、试听并交付大型音效素材库。",
    installReapack: "通过 ReaPack 安装",
    downloadStable: "下载稳定版",
    viewPreview: "查看 0.9 新功能 ↓",
    freeUpdate: "一个仓库 · 自动更新",
    inlineWaveforms: "列表内联波形",
    visibleFirst: "可见内容优先缓存",
    nonDestructive: "非破坏性管理",
    sourceSafe: "源媒体始终保持不变",
    insideReaper: "运行于 REAPER",
    oneWorkspace: "一个可停靠工作区",
    largeLibraries: "面向大型素材库",
    boundedWork: "有界后台任务",
    waveformFirst: "以波形为核心",
    seekSelect: "定位、选区与交付",
    bilingual: "双语界面",
    englishChinese: "English 与简体中文",
    desktopPreviewLabel: "桌面伴侣 · ALPHA 8",
    desktopPreviewTitle: "打开工程前，先进入你的音效库。",
    desktopPreviewText: "Windows x64 独立伴侣：逻辑库、快速搜索、波形、试听、Artwork、收藏和把文件拖入 REAPER。",
    releaseKicker: "0.9 正式版已发布",
    releaseHeading: "完整的 0.9 工作区，现已正式发布。",
    stableChannel: "稳定通道",
    stableSummary: "默认 ReaPack 版本，适合日常生产使用。",
    getStable: "获取稳定版 ↗",
    previewChannel: "0.9 新功能",
    previewSummary: "UCS 分类、声学／神经相似检索、独立 AI 语义搜索与 API 预设、自定义字体、文件夹导航、浏览标签快照、Watch Folder 开关及具体厂商产品包定位。正式版包含 Beta 8.7 全部功能。",
    getPreview: "查看 0.9 发布说明 ↗",
    neuralAddon: "直接下载完整神经包 ZIP · Windows x64 ↗",
    neuralInstallNote: "普通 ReaPack 同步即可更新 PsyReaSFX.lua 至 0.9.0 正式版。神经检索需另装<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">PsyReaSFX Neural Similarity 附加包</a>；两者均无需启用预发布。Versions 保留 0.9.0、0.8.5 和 0.7.23 正式版。",
    downloadDesktop: "下载桌面 Alpha 8",
    desktopGuide: "桌面版说明 ↗",
    completeLoop: "完整的音效素材库工作闭环",
    fourMoves: "四个环节，一个工作区。",
    fourMovesLead: "将发现、决策与交付保持在同一上下文中，不再频繁切换和重建工作状态。",
    discover: "发现",
    discoverText: "搜索文件名与元数据，浏览索引目录，并从列表波形的任意位置开始试听。",
    organize: "整理",
    organizeText: "将多个文件夹聚合为一个逻辑库，再通过封面、元数据、集合与状态完成管理。",
    audition: "试听",
    auditionText: "检查各声道波形、建立循环选区、调整 Pitch、Rate、Gain 并比较响度。",
    deliver: "交付",
    deliverText: "插入或拖入 REAPER、保留 BWF 位置，或者使用 Transfer 渲染处理后的变体。",
    librariesKicker: "符合真实存储结构的音效库",
    oneNameManyFolders: "一个音效库名称，<br>聚合任意数量的来源路径。",
    oneNameText: "先创建逻辑音效库，再逐步连接不同硬盘上的文件夹。每个来源独立保留路径、在线状态与封面。",
    folderDrag: "直接从资源管理器拖入文件夹",
    indexedHierarchy: "无需重新扫描即可浏览索引目录层级",
    sourceArtwork: "封面始终归属于正确的实体来源",
    waveformKicker: "从波形直接进入时间线",
    hearItPlaceIt: "听见它，塑造它，<br>然后放进工程。",
    hearItText: "点击内联波形即可从准确位置开始试听；在大波形中建立精确选区后，可以直接拖入 REAPER 编排区。",
    channelLanes: "单声道、立体声与多声道波形",
    regionsTransient: "Region 与瞬态建议",
    loudnessStats: "LUFS 与 True Peak 数据",
    findKicker: "按结构与声音查找",
    findTitle: "先搜索目录，<br>再搜索声音本身。",
    findText: "不同音效库与搜索可分标签浏览。Ctrl+N 新建，Ctrl+Shift+N 复制，Ctrl+W 关闭，Ctrl+Tab 切换；已完成 AI/相似结果在本会话保留，切换不再次调用 API。",
    ucsNavigation: "按 Category、SubCategory 和 CatID 浏览，不移动源文件",
    aiSemanticSearch: "用 DeepSeek 或 OpenAI-compatible API 理解一次自然语言描述，再在本地排序匹配的素材元数据",
    similarSearch: "常见采样率、位深与格式均可本地神经召回；<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">必须另装神经包</a>，不可用时回退声学检索",
    spectralPeaks: "在详细波形中按需查看频谱峰值",
    similarityDetails: "阅读相似声音架构 ↗",
    aiSemanticDetails: "阅读 AI 语义搜索架构 ↗",
    deliverWithoutLosing: "交付素材，不中断设计思路。",
    transferLead: "通过可重复使用的设置，将完整源文件、波形选区或受控批量变体生成新的音频文件。",
    smartTail: "智能源文件尾音",
    batchVariants: "批量变体",
    designedDepth: "为深度工作而设计",
    dailyFast: "日常操作足够快，<br>复杂项目也足够深。",
    metadataTitle: "元数据与封面",
    metadataText: "维护非破坏性数据库、固定封面，并始终保护源文件。",
    searchTitle: "搜索与筛选",
    searchText: "组合文本、音效库、UCS 字段、标记与工作流状态。",
    organizeTitle: "集合整理",
    collectionsText: "建立播放列表、项目素材箱、收藏和可复用的保存搜索。",
    performanceTitle: "大型库性能",
    performanceText: "可见项优先、有界任务队列和持久波形缓存让浏览保持流畅。",
    channelTitle: "声道感知预览",
    channelText: "支持单声道、立体声及最多八条独立高精度波形。",
    reaperTitle: "REAPER 交付",
    reaperText: "插入当前轨、新轨、BWF 原始位置，或拖入当前波形选区。",
    comparisonKicker: "版本差异",
    comparisonHeading: "0.9 正式版多了哪些功能？",
    comparisonLead: "仅比较 REAPER / Lua 版，不含桌面伴侣。0.9 包含历史稳定版功能；“—”表示该版本没有此功能。",
    comparisonScroll: "小屏幕可左右滑动表格，查看所有版本。",
    comparisonCaption: "功能概览 · 0.7.23 / 0.8.5 / 0.9.0 Stable",
    comparisonFeature: "功能",
    comparisonLatest: "当前正式版",
    comparisonDetails: "查看完整更新日志 ↗",
    betaGuideLink: "更新 0.9 正式版：图解步骤 ↓",
    betaGuideKicker: "更新正式版",
    betaGuideHeading: "普通 ReaPack 同步即可更新 0.9.0。",
    betaGuideLead: "0.9.0 已成为默认正式版，无需启用预发布。如果固定了旧版本，先取消固定。",
    betaStepOne: "执行 扩展 → ReaPack → 同步软件包，再打开 浏览软件包 / Browse packages，搜索 PsyReaSFX。",
    betaStepTwo: "右键主程序 PsyReaSFX.lua；若固定了旧版，取消 <strong>Pin current version</strong>。",
    betaStepThree: "选择 <strong>Install</strong>，或 <strong>Versions → 0.9.0</strong> 正式版。预发布开关仅用于将来的测试版本。",
    betaStepFour: "点击 <strong>Apply</strong>，或 <strong>OK</strong> 确认应用安装。下载完成后关闭旧 PsyReaSFX 窗口，从 REAPER 动作列表重新运行。",
    betaNeuralNote: "<strong>本地神经相似检索必须另装包：</strong>仅支持 Windows x64。<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">直接下载完整 PsyReaSFX Neural Similarity ZIP</a>（约 42.4 MB，含模型与安装脚本），或在 ReaPack 安装独立数据包；更新主脚本不会自动安装。<a href=\"#neural-install\">具体安装步骤 ↓</a>。未安装时使用内置 15 维声学检索。",
    betaAiNote: "<strong>AI 语义搜索：</strong>无需<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">神经包</a>。在设置中创建、保存并切换 DeepSeek / OpenAI / 兼容 API 预设，每组 Key 与模型独立。回车执行普通搜索，金色 AI 按钮执行语义搜索，不上传音频。",
    betaDataNote: "无需强制重建音效库；Beta 8.5 及更新神经组件、现有缓存继续兼容 0.9.0。",
    betaScreenshotLabel: "查看历史 ReaPack 菜单示例原图",
    betaScreenshotCaption: "保留历史 Beta 截图说明菜单位置。Versions 现在列出 0.9.0、0.8.5 和 0.7.23 正式版，旧 Beta 仍在 GitHub Releases；安装 0.9.0 无需启用预发布。",
    compareIncluded: "有",
    compareRetained: "保留",
    compareNone: "—",
    compareAdded: "新增",
    compareRefined: "保留并改进",
    compareEarly: "早期实现",
    compareHardened: "强化",
    compareStartup: "进一步优化启动",
    compareUcsFields: "仅基础 UCS 字段",
    compareOptIn: "新增；按需启用",
    compare15Features: "主程序内置 15 维声学检索",
    compareAddon: "<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">神经检索必装包 · Windows x64 ZIP ↗</a>",
    compareApi: "自备 API Key / 模型；无需<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">神经包</a>",
    compareNoDelay: "新增；无固定动画等待",
    compareFont: "10–24 px 字号联动缩放与波形列适配",
    compareFolders: "侧栏目录层级/根目录与模块开关",
    compareTabs: "独立搜索 / 浏览标签页",
    compareTabsEntry: "新增；搜索下方 + / Ctrl+N",
    compareWorkspaceEntry: "新增；设置 → 字体与导航",
    compareCore: "浏览、波形试听、元数据、集合与 Transfer",
    compareRecovery: "中断恢复、失败重试、自动备份与缓存检查",
    compareMaintenance: "缺失/重复素材检查、来源重定位与工程使用记录",
    comparePerformance: "大型库增量保存与分帧任务",
    compareUcs: "官方 UCS 自动分类、待确认队列与虚拟目录",
    compareSpectral: "频谱峰值着色",
    compareAcoustic: "基于音频内容的相似声音检索",
    compareNeural: "EfficientAT 本地神经相似声音",
    compareAi: "AI 语义搜索：本地召回、分页与命名 API 预设",
    compareAnimation: "品牌启动动画与实时加载状态",
    neuralGuideLink: "神经包安装：ReaPack / ZIP 步骤 ↓",
    neuralInstallKicker: "神经相似声音检索必装",
    neuralInstallHeading: "下载附加包，不是只更新主脚本。",
    neuralInstallLead: "同一个“相似声音”入口自动选择两种引擎：基础 15 维声学检索无需下载；EfficientAT 神经检索必须安装 <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">PsyReaSFX Neural Similarity</a>。AI 语义搜索是独立功能，需要自行配置 API，不需要这个包。",
    neuralZipDownload: "直接下载完整神经包 ZIP ↗",
    neuralDownloadNote: "Windows x64 · 0.9.0 · 约 42.4 MB。包含程序、模型与安装脚本；Release 裸 EXE 不含模型。下方两种安装方式任选一种即可。",
    neuralReapackHeading: "推荐：在 REAPER 内安装",
    neuralReapackOne: "导入上方仓库地址并同步，再打开 <strong>扩展 → ReaPack → 浏览软件包 / Browse packages</strong>。",
    neuralReapackTwo: "搜索 <a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">PsyReaSFX Neural Similarity</a>，选中独立<strong>数据包</strong>，不是 PsyReaSFX.lua 主脚本。",
    neuralReapackThree: "选择 <strong>Install</strong> 或 <strong>Versions → 0.9.0</strong> 正式版；需要时取消 <strong>Pin current version</strong>，无需启用预发布。",
    neuralReapackFour: "点击 <strong>Apply / OK</strong>，等待下载结束，关闭旧 PsyReaSFX 窗口并重新运行。ReaPack 会一起安装、更新程序和模型。",
    neuralReapackPath: "安装到 <code>&lt;REAPER 资源目录&gt;\\Data\\PsyReaSFX\\neural_similarity\\</code>。",
    neuralManualHeading: "备用：完整 ZIP 手动安装",
    neuralManualOne: "点击<a data-neural-download href=\"https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip\">完整神经包 ZIP 精确下载</a>，<strong>全部解压</strong>，不要在压缩包内直接运行安装脚本。",
    neuralManualTwo: "双击 <code>Install-NeuralSimilarity.cmd</code>，提示成功后重新启动 PsyReaSFX。",
    neuralManualThree: "便携版 REAPER 请通过 <strong>Options → Show REAPER resource path / 显示 REAPER 资源路径</strong> 确认目录，再按安装说明指定该目录。",
    neuralManualPath: "手动安装默认目录：<code>%APPDATA%\\REAPER\\Scripts\\PsyReaSFX\\neural_similarity\\</code>。",
    neuralInstallerGuide: "便携版与手动安装说明 ↗",
    neuralAfterInstall: "无需另装 Python 或 .NET，不上传音频，不生成转码副本。首次使用会建立可取消的特征缓存与 HNSW 索引；组件缺失或异常时自动回退基础声学检索。",
    quickStart: "快速开始",
    installOnce: "安装一次，<br>以后在 REAPER 内更新。",
    installLead: "在 ReaPack 中导入并同步仓库，再安装 PsyReaSFX 0.9.0 正式版。Beta 8.7 全部功能现已进入默认更新通道。",
    stepOne: "打开 Extensions → ReaPack → Import repositories…",
    stepTwo: "粘贴下方仓库地址。",
    stepThree: "同步软件包，搜索 PsyReaSFX，安装 0.9.0 正式版。",
    copy: "复制",
    copied: "已复制",
    host: "宿主",
    required: "必需",
    recommended: "推荐",
    downloadLatest: "下载最新稳定版",
    learnAndBuild: "学习与深入使用",
    docsWhenNeeded: "需要深入时，完整细节都在这里。",
    userGuide: "用户使用说明书",
    userGuideText: "完整工作流、控件说明与故障排查。",
    changelog: "更新日志",
    changelogText: "了解修改内容、修改原因和兼容性说明。",
    issueTracker: "问题反馈",
    issueText: "提交可复现问题，或跟进项目开发进度。",
    roadmap: "0.9 → 1.0 路线图",
    roadmapText: "查看功能边界、验收门槛与神经相似度计划。",
    soundAssetsOrganized: "让音效素材井然有序",
    stayInFlow: "专注声音，保持工作流。",
    getPsy: "获取 PsyReaSFX",
    releases: "版本发布"
  }
};

function applyLanguage(language) {
  const selected = messages[language] ? language : "en";
  document.documentElement.lang = selected === "zh" ? "zh-CN" : "en";
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const value = messages[selected][element.dataset.i18n];
    if (typeof value === "string") {
      element.innerHTML = value;
    }
  });
  document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    const value = messages[selected][element.dataset.i18nAriaLabel];
    if (typeof value === "string") element.setAttribute("aria-label", value);
  });
  document.title = messages[selected].pageTitle;
  document.querySelector('meta[name="description"]')
    ?.setAttribute("content", messages[selected].pageDescription);

  const current = document.querySelector(".language-current");
  const other = document.querySelector(".language-other");
  if (current && other) {
    current.textContent = selected === "zh" ? "中文" : "EN";
    other.textContent = selected === "zh" ? "EN" : "中文";
    const toggle = document.querySelector("[data-language-toggle]");
    toggle?.setAttribute(
      "aria-label",
      `${current.textContent} / ${other.textContent} — ${messages[selected].languageLabel}`
    );
  }

  document.querySelectorAll("[data-transfer-image]").forEach((image) => {
    image.src = selected === "zh"
      ? "assets/screenshots/transfer-settings-zh.png"
      : "assets/screenshots/transfer-settings-en.png";
  });
  document.querySelectorAll("[data-transfer-source]").forEach((source) => {
    source.srcset = selected === "zh"
      ? "assets/screenshots/transfer-settings-zh-960.webp 960w, assets/screenshots/transfer-settings-zh.webp 1700w"
      : "assets/screenshots/transfer-settings-en-960.webp 960w, assets/screenshots/transfer-settings-en.webp 1700w";
  });

  document.querySelectorAll('a[href*="USER_GUIDE_"]').forEach((link) => {
    link.href = `https://github.com/${REPOSITORY}/blob/main/docs/USER_GUIDE_${selected === "zh" ? "zh-CN" : "en-US"}.md`;
  });
  document.querySelectorAll('a[href*="CHANGELOG_"]').forEach((link) => {
    link.href = `https://github.com/${REPOSITORY}/blob/main/docs/CHANGELOG_${selected === "zh" ? "zh-CN" : "en-US"}.md`;
  });
  document.querySelectorAll("[data-desktop-guide]").forEach((link) => {
    link.href = `https://github.com/${REPOSITORY}/blob/main/docs/DESKTOP_PREVIEW_${selected === "zh" ? "zh-CN" : "en-US"}.md`;
  });

  document.querySelectorAll("[data-neural-install-guide]").forEach((link) => {
    link.href = `https://github.com/${REPOSITORY}/blob/main/neural/package/${selected === "zh" ? "README_zh-CN.md" : "README.md"}`;
  });
  // Language rendering recreates links. Preserve the matching release URL.
  applyNeuralDownloadLinks();
  localStorage.setItem("psyreasfx-language", selected);
}

function formatReleaseVersion(tagName) {
  return String(tagName || "")
    .replace(/^v/, "")
    .replace(/-beta/i, " Beta ");
}

function findLuaArchive(release) {
  return (release?.assets || []).find((item) =>
    /^PsyReaSFX_v(?!.*Desktop).*\.zip$/i.test(item.name)
  );
}

function updateReleaseLink(selector, release, fallback) {
  const archive = findLuaArchive(release);
  const url = archive?.browser_download_url || release?.html_url || fallback.url;
  document.querySelectorAll(selector).forEach((link) => {
    link.href = url;
  });
}

function findNeuralArchive(release) {
  return (release?.assets || []).find((item) =>
    /^PsyReaSFX_Neural_Similarity_v[\d_]+(?:_beta[\d_]+)?_win_x64\.zip$/i.test(item.name)
  );
}

function applyNeuralDownloadLinks() {
  document.querySelectorAll("[data-neural-download]").forEach((link) => {
    link.href = neuralDownloadUrl;
  });
}

function updateNeuralDownload(release) {
  const archive = findNeuralArchive(release);
  // Never substitute the Lua ZIP, a bare EXE, or a release landing page.
  // If a newer Lua-only release has no neural archive, keep the verified ZIP.
  if (archive?.browser_download_url) neuralDownloadUrl = archive.browser_download_url;
  applyNeuralDownloadLinks();
}

async function updateReleaseChannels() {
  try {
    const response = await fetch(`https://api.github.com/repos/${REPOSITORY}/releases?per_page=30`, {
      headers: { Accept: "application/vnd.github+json" }
    });
    if (!response.ok) return;
    const releases = await response.json();
    const stable = releases.find((release) =>
      !release.draft && !release.prerelease && /^v\d/i.test(release.tag_name)
    );
    const desktopAsset = releases.flatMap((release) => release.assets || [])
      .find((item) => /PsyReaSFX_Desktop_.*win_x64\.zip$/i.test(item.name));

    document.querySelectorAll("[data-stable-version]").forEach((element) => {
      element.textContent = formatReleaseVersion(stable?.tag_name) || STABLE_FALLBACK.version;
    });
    updateReleaseLink("[data-stable-download]", stable, STABLE_FALLBACK);
    updateNeuralDownload(stable);
    document.querySelectorAll("[data-desktop-download]").forEach((link) => {
      if (desktopAsset) link.href = desktopAsset.browser_download_url;
    });
  } catch {
    // Static fallbacks remain fully usable when the GitHub API is unavailable.
  }
}

function installCopyAction() {
  const button = document.querySelector("[data-copy-reapack]");
  if (!button) return;

  button.addEventListener("click", async () => {
    const language = document.documentElement.lang.startsWith("zh") ? "zh" : "en";
    try {
      await navigator.clipboard.writeText(REAPACK_URL);
      button.querySelector("span").textContent = messages[language].copied;
      window.setTimeout(() => {
        button.querySelector("span").textContent = messages[language].copy;
      }, 1600);
    } catch {
      const range = document.createRange();
      range.selectNodeContents(document.querySelector("#reapack-url"));
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
    }
  });
}

document.addEventListener("DOMContentLoaded", () => {
  const storedLanguage = localStorage.getItem("psyreasfx-language");
  const preferredLanguage = storedLanguage
    || (navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en");
  applyLanguage(preferredLanguage === "zh" ? "zh" : "en");

  document.querySelector("[data-language-toggle]")?.addEventListener("click", () => {
    applyLanguage(document.documentElement.lang.startsWith("zh") ? "en" : "zh");
  });

  installCopyAction();
  updateReleaseChannels();
});
