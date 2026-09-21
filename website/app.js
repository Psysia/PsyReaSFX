const REPOSITORY = "Psysia/PsyReaSFX";
const REAPACK_URL = "https://github.com/Psysia/PsyReaSFX/raw/main/index.xml";
const STABLE_FALLBACK = {
  version: "0.8.5",
  url: "https://github.com/Psysia/PsyReaSFX/releases/tag/v0.8.5"
};
const PREVIEW_FALLBACK = {
  version: "0.9.0 Beta 7.8",
  url: "https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.0-beta7.8"
};

const messages = {
  en: {
    skip: "Skip to content",
    homeLabel: "PsyReaSFX home",
    primaryNavLabel: "Primary navigation",
    languageLabel: "Switch language",
    githubLabel: "View PsyReaSFX on GitHub",
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
    viewPreview: "View Beta 7.8",
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
    releaseKicker: "CHOOSE YOUR RELEASE TRACK",
    releaseHeading: "Stable for production. Preview what is next.",
    stableChannel: "Stable channel",
    stableSummary: "The default ReaPack release for everyday production work.",
    getStable: "Get Stable ↗",
    previewChannel: "Preview channel",
    previewSummary: "Separate AI semantic search with DeepSeek and compatible APIs, plus optional local EfficientAT similarity.",
    getPreview: "View preview ↗",
    neuralAddon: "Install both packages with ReaPack ↓",
    neuralInstallNote: "Enable pre-release versions and install PsyReaSFX.lua Beta 7.8. On Windows x64, install the matching optional PsyReaSFX Neural Similarity package if needed.",
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
    findText: "Beta 7.8 uses AI once to understand the query, then ranks and pages up to 2,400 candidates locally without uploading asset metadata.",
    ucsNavigation: "Browse Category, SubCategory and CatID without moving source files",
    aiSemanticSearch: "Use DeepSeek or an OpenAI-compatible API once to expand a natural-language request, then rank matching metadata locally",
    similarSearch: "Use local neural recall across common sample rates, bit depths and formats, with safe automatic fallback",
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
    quickStart: "QUICK START",
    installOnce: "Install once.<br>Update inside REAPER.",
    installLead: "Import and synchronize the repository, enable package pre-releases, and install PsyReaSFX.lua Beta 7.8. On Windows x64, repeat for the matching optional PsyReaSFX Neural Similarity package. Both update through the same URL.",
    stepOne: "Open Extensions → ReaPack → Import repositories…",
    stepTwo: "Paste the repository URL below.",
    stepThree: "Enable pre-releases and install PsyReaSFX.lua Beta 7.8; on Windows x64, repeat for PsyReaSFX Neural Similarity if needed.",
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
    skip: "跳到主要内容",
    homeLabel: "PsyReaSFX 首页",
    primaryNavLabel: "主导航",
    languageLabel: "切换语言",
    githubLabel: "在 GitHub 查看 PsyReaSFX",
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
    viewPreview: "查看 Beta 7.8",
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
    releaseKicker: "选择适合你的发布通道",
    releaseHeading: "稳定版用于生产，预发布体验下一阶段。",
    stableChannel: "稳定通道",
    stableSummary: "默认 ReaPack 版本，适合日常生产使用。",
    getStable: "获取稳定版 ↗",
    previewChannel: "预发布通道",
    previewSummary: "独立 AI 语义搜索支持 DeepSeek 与兼容接口，并保留可选的本地 EfficientAT 相似检索。",
    getPreview: "查看预发布版 ↗",
    neuralAddon: "通过 ReaPack 安装两个包 ↓",
    neuralInstallNote: "先启用预发布并安装 PsyReaSFX.lua Beta 7.8；Windows x64 如需神经检索，再安装配套的可选包 PsyReaSFX Neural Similarity。",
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
    findText: "Beta 7.8 只调用一次 AI 理解查询，随后最多 2400 条候选均在本地排序和分页，不上传素材元数据。",
    ucsNavigation: "按 Category、SubCategory 和 CatID 浏览，不移动源文件",
    aiSemanticSearch: "用 DeepSeek 或 OpenAI-compatible API 理解一次自然语言描述，再在本地排序匹配的素材元数据",
    similarSearch: "常见采样率、位深与格式均可使用本地神经召回，并在异常时安全回退",
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
    quickStart: "快速开始",
    installOnce: "安装一次，<br>以后在 REAPER 内更新。",
    installLead: "在 ReaPack 中导入并同步仓库，为软件包启用预发布后安装 PsyReaSFX.lua Beta 7.8；Windows x64 用户如需神经检索，再安装配套的可选包 PsyReaSFX Neural Similarity。两个包都通过同一地址更新。",
    stepOne: "打开 Extensions → ReaPack → Import repositories…",
    stepTwo: "粘贴下方仓库地址。",
    stepThree: "启用预发布并安装 PsyReaSFX.lua Beta 7.8；Windows x64 如需神经检索，再对 PsyReaSFX Neural Similarity 执行同样操作。",
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
    const preview = releases.find((release) =>
      !release.draft && release.prerelease && /^v\d/i.test(release.tag_name)
    );
    const desktopAsset = releases.flatMap((release) => release.assets || [])
      .find((item) => /PsyReaSFX_Desktop_.*win_x64\.zip$/i.test(item.name));

    document.querySelectorAll("[data-stable-version]").forEach((element) => {
      element.textContent = formatReleaseVersion(stable?.tag_name) || STABLE_FALLBACK.version;
    });
    document.querySelectorAll("[data-preview-version]").forEach((element) => {
      element.textContent = formatReleaseVersion(preview?.tag_name) || PREVIEW_FALLBACK.version;
    });
    updateReleaseLink("[data-stable-download]", stable, STABLE_FALLBACK);
    updateReleaseLink("[data-preview-download]", preview, PREVIEW_FALLBACK);
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
