import { connectHost } from "./host.js";
import { createLocalizer } from "./locale.js";
import { createSettings, transferPresets } from "./settings.js";
import { icon } from "./icons.js";

const $ = (id) => document.getElementById(id);
const defaults = {
  version: 1,
  theme: "dark",
  language: "zh",
  left: false,
  right: true,
  leftWidth: 206,
  rightWidth: 290,
  auditionHeight: 282,
  rowHeight: 29,
  fontSize: 13,
  fontFamily: "Segoe UI",
  accentColor: "#c7b57f",
  surfaceColor: "#222426",
  waveformColorMode: "theme",
  waveformSelectionColor: "#c7b57f",
  navigationPanel: "libraries",
  navigation: {},
  collapsedLibraries: [],
  fx: false,
  columns: {
    index: false,
    star: true,
    waveform: true,
    name: true,
    description: true,
    duration: true,
    channels: false,
    library: false,
    catid: false,
  },
  widths: {
    index: 45,
    star: 30,
    waveform: 330,
    name: 280,
    description: 370,
    duration: 95,
    channels: 52,
    library: 160,
    catid: 90,
  },
};
let prefs;
try {
  const saved = JSON.parse(
    localStorage.getItem("psyreasfx.workspace.v1") || "null",
  );
  prefs =
    saved?.version === 1
      ? {
          ...defaults,
          ...saved,
          columns: { ...defaults.columns, ...saved.columns },
          widths: { ...defaults.widths, ...saved.widths },
        }
      : structuredClone(defaults);
} catch {
  prefs = structuredClone(defaults);
}

const localizer = createLocalizer();
localizer.setLanguage(prefs.language);
let host;
let snapshot;
let page;
let pageSequence = 0;
let pageRequestAgain = false;
let waveSequence = 0;
let detailWave;
let detailPaintKey;
let detailPaintWave;
const fullMetadata = new Map();
let inspectorTab = "metadata";
let sidebarSignature;
let tabsSignature;
let dirtyFields = {};
let originalFields = {};
let artworkUrl;
let zoomStart = 0;
let zoomEnd = 1;
let regionDrag;
let sortDescending = false;
let pageRetry;
let waveRetry;
let transferDraft = {};
let reportTimer;
let waveFailure = "";
let pageTask;
let lastPageKey;
let lastPageContent;
const folderOpen = new Set();
let ucsCatalog;
let ucsLoading;
const ucsOpen = new Set();
const tabScroll = new Map();
const metadataDrafts = new Map();
const columnDefinitions = [
  ["index", "序号"],
  ["star", "收藏"],
  ["waveform", "预览波形"],
  ["name", "文件名"],
  ["description", "描述 / 关键词"],
  ["duration", "时长"],
  ["channels", "声道"],
  ["library", "音效库"],
  ["catid", "CatID"],
  ["workflowLabel", "工作流状态"],
  ["category", "Category"],
  ["subcategory", "Subcategory"],
  ["sampleRate", "采样率"],
  ["bitDepth", "位深"],
  ["format", "格式"],
  ["path", "完整路径"],
  ["previewCount", "试听次数"],
  ["usedCount", "使用次数"],
  ["similarity", "相似度"],
  ["artwork_path", "封面"],
];

function node(tag, className, content) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (content !== undefined) element.textContent = content;
  return element;
}

function report(error) {
  $("status").textContent = error?.message || String(error);
  $("status").classList.add("error");
  $("toast-message").textContent = error?.message || String(error);
  $("toast").hidden = false;
  clearTimeout(reportTimer);
  reportTimer = setTimeout(() => {
    $("toast").hidden = true;
  }, 9000);
  if ($("settings-dialog").open) {
    let message = $("dialog-status");
    if (!message) {
      message = node("p", "error");
      message.id = "dialog-status";
      message.setAttribute("role", "status");
      $("settings-body").append(message);
    }
    message.textContent = error?.message || String(error);
  }
}

function action(callback) {
  return (...args) => {
    try {
      return Promise.resolve(callback(...args)).catch(report);
    } catch (error) {
      report(error);
    }
  };
}

function command(method, params) {
  if (!host) return Promise.reject(new Error("宿主尚未连接"));
  if (
    method === "records.action" &&
    params?.action === "saveSearch" &&
    params.name === undefined
  )
    return saveSearch();
  if (["catalog.query", "catalog.sort", "tab.action"].includes(method))
    pageSequence++;
  if (method === "diagnostics.get")
    return host.request(method, params).then(async (text) => {
      const keyboard = await host.keyboardState?.().catch((error) => ({
        error: error.message,
      }));
      return `${text}\nWebView runtime: ${JSON.stringify(host.runtime || {})}\nWindow keyboard: ${JSON.stringify(keyboard || { transport: "desktop" })}`;
    });
  return host.request(method, params);
}

function time(seconds) {
  const value = Math.max(0, Number(seconds) || 0);
  const minutes = Math.floor(value / 60);
  return `${String(minutes).padStart(2, "0")}:${(value % 60).toFixed(3).padStart(6, "0")}`;
}

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, Number(value) || minimum));
}

function persist() {
  try {
    localStorage.setItem("psyreasfx.workspace.v1", JSON.stringify(prefs));
  } catch {
    /* Full browser storage must not interrupt audition. */
  }
}

function applyPreferences() {
  prefs.leftWidth = clamp(prefs.leftWidth, 140, 420);
  prefs.rightWidth = clamp(prefs.rightWidth, 220, 480);
  prefs.rowHeight = clamp(
    prefs.rowHeight,
    Math.max(24, prefs.fontSize + 10),
    52,
  );
  prefs.fontSize = clamp(prefs.fontSize, 10, 24);
  document.body.dataset.theme = prefs.theme === "paper" ? "paper" : "dark";
  document.body.classList.toggle("left-hidden", !prefs.left);
  document.body.classList.toggle("right-hidden", !prefs.right);
  const style = document.documentElement.style;
  style.setProperty("--sidebar-left", `${prefs.leftWidth}px`);
  style.setProperty("--sidebar-right", `${prefs.rightWidth}px`);
  layoutAudition();
  document.body.classList.toggle("fx-open", Boolean(prefs.fx));
  style.setProperty("--row-height", `${prefs.rowHeight}px`);
  style.setProperty("--font-size", `${prefs.fontSize}px`);
  if (prefs.fontFamily) document.body.style.fontFamily = prefs.fontFamily;
  $("fx-panel").open = prefs.fx;
  $("fx-toggle").setAttribute("aria-expanded", String(prefs.fx));
  $("left-toggle").setAttribute("aria-expanded", String(prefs.left));
  $("right-toggle").setAttribute("aria-expanded", String(prefs.right));
  if (prefs.theme !== "paper") {
    style.setProperty("--accent", prefs.accentColor || defaults.accentColor);
    style.setProperty("--surface", prefs.surfaceColor || defaults.surfaceColor);
  } else {
    style.removeProperty("--accent");
    style.removeProperty("--surface");
  }
  renderColumns();
  renderRows();
  updateNavigation();
  requestAnimationFrame(drawDetail);
}

function layoutAudition() {
  // Keep the waveform's saved height independent of temporary controls.
  const extra = (prefs.fx ? 48 : 0) + ($("analysis-bar").hidden ? 0 : 28);
  prefs.auditionHeight = clamp(
    prefs.auditionHeight,
    192,
    Math.max(192, innerHeight - 300 - extra),
  );
  document.documentElement.style.setProperty(
    "--audition-height",
    `${prefs.auditionHeight + extra}px`,
  );
}

function orderedColumns() {
  const order = prefs.columnOrder || columnDefinitions.map(([key]) => key);
  return [...columnDefinitions].sort((a, b) => {
    const rank = (key) =>
      order.includes(key) ? order.indexOf(key) : order.length;
    return rank(a[0]) - rank(b[0]);
  });
}
function visibleColumns() {
  return orderedColumns().filter(([key]) => prefs.columns[key]);
}

function width(key) {
  return clamp(
    prefs.widths[key] ?? defaults.widths[key] ?? 140,
    key === "star" ? 28 : 45,
    1200,
  );
}

function renderColumns() {
  const fragment = document.createDocumentFragment();
  for (const [key, label] of visibleColumns()) {
    const title = node("div", "column-title", key === "star" ? "☆" : label);
    title.style.width = `${width(key)}px`;
    title.dataset.column = key;
    title.setAttribute("role", "columnheader");
    if (["name", "duration", "library"].includes(key)) {
      title.onclick = action(() => {
        $("sort").value = key;
        return command("catalog.sort", {
          field: key,
          descending: sortDescending,
        });
      });
    }
    const grip = node("span", "column-resize");
    grip.onpointerdown = (event) => resizeColumn(event, key);
    grip.onclick = (event) => event.stopPropagation();
    title.append(grip);
    fragment.append(title);
  }
  $("column-head").replaceChildren(fragment);
  const totalWidth = visibleColumns().reduce(
    (sum, [key]) => sum + width(key),
    0,
  );
  $("result-space").style.width = `${totalWidth}px`;
  $("visible-rows").style.width = `${totalWidth}px`;
}

function resizeColumn(event, key) {
  event.stopPropagation();
  event.preventDefault();
  const origin = event.clientX;
  const original = width(key);
  const grip = event.currentTarget;
  grip.setPointerCapture(event.pointerId);
  const move = (moved) => {
    prefs.widths[key] = clamp(
      original + moved.clientX - origin,
      key === "star" ? 28 : 60,
      1200,
    );
    for (const element of document.querySelectorAll(`[data-column="${key}"]`))
      element.style.width = `${width(key)}px`;
    const totalWidth = visibleColumns().reduce(
      (sum, [column]) => sum + width(column),
      0,
    );
    $("result-space").style.width = `${totalWidth}px`;
    $("visible-rows").style.width = `${totalWidth}px`;
  };
  const finish = () => {
    grip.removeEventListener("pointermove", move);
    persist();
    renderColumns();
    renderRows();
  };
  grip.addEventListener("pointermove", move);
  grip.addEventListener("pointerup", finish, { once: true });
  grip.addEventListener("pointercancel", finish, { once: true });
}

function spectralColor(wave, index, fallback) {
  if (!wave?.spectralFrequency?.length) return fallback;
  const frequency = clamp(wave.spectralFrequency[index] || 20, 20, 20000);
  const t = Math.log(frequency / 20) / Math.log(1000);
  const stops = [
    [89, 100, 239],
    [32, 185, 214],
    [99, 211, 110],
    [242, 180, 92],
  ];
  const segment = t < 0.34 ? 0 : t < 0.68 ? 1 : 2;
  const fraction =
    (t - [0, 0.34, 0.68][segment]) / (segment === 2 ? 0.32 : 0.34);
  const fallbackParts = fallback.startsWith("#")
    ? fallback
        .slice(1)
        .match(/.{2}/g)
        ?.slice(0, 3)
        .map((value) => parseInt(value, 16))
    : fallback
        .match(/[\d.]+/g)
        ?.slice(0, 3)
        .map(Number);
  const mix = 0.34 + clamp(wave.spectralTonality?.[index] || 0, 0, 1) * 0.66;
  const color = stops[segment].map((value, channel) =>
    Math.round(
      (fallbackParts?.[channel] ?? value) * (1 - mix) +
        (value + (stops[segment + 1][channel] - value) * fraction) * mix,
    ),
  );
  return `rgb(${color.join(",")})`;
}

function drawPeaks(canvas, waveform, color, selected = false) {
  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  const ratio = Math.min(devicePixelRatio || 1, 2);
  canvas.width = Math.round(rect.width * ratio);
  canvas.height = Math.round(rect.height * ratio);
  const context = canvas.getContext("2d");
  context.scale(ratio, ratio);
  context.strokeStyle = color;
  if (!waveform?.peaks?.length) {
    context.globalAlpha = 0.15;
    context.beginPath();
    context.moveTo(0, rect.height / 2);
    context.lineTo(rect.width, rect.height / 2);
    context.stroke();
    return;
  }
  const values = waveform.peaks;
  context.globalAlpha = selected ? 1 : 0.85;
  context.beginPath();
  for (let x = 0; x < rect.width; x++) {
    const start = Math.floor((x / rect.width) * values.length);
    const end = Math.max(
      start + 1,
      Math.ceil(((x + 1) / rect.width) * values.length),
    );
    let peak = 0;
    for (let i = start; i < end; i++)
      peak = Math.max(peak, Math.abs(values[i] || 0));
    if (waveform.spectralFrequency?.length) {
      context.stroke();
      context.beginPath();
      context.strokeStyle = spectralColor(waveform, start, color);
    }
    const height = Math.max(0.5, Math.min(1, peak) * (rect.height / 2 - 1));
    context.moveTo(x + 0.5, rect.height / 2 - height);
    context.lineTo(x + 0.5, rect.height / 2 + height);
  }
  context.stroke();
}

function attachArrangeDrag(element, assetPath, selection) {
  let gesture;
  element.addEventListener("pointerdown", (event) => {
    if (
      event.button !== 0 ||
      event.altKey ||
      event.target.closest(".waveform,.star")
    )
      return;
    gesture = { x: event.clientX, y: event.clientY, active: false };
  });
  element.addEventListener("pointermove", (event) => {
    if (!gesture || !(event.buttons & 1)) return;
    if (Math.hypot(event.clientX - gesture.x, event.clientY - gesture.y) > 6) {
      gesture.active = true;
      element.setPointerCapture(event.pointerId);
      element.style.cursor = "grabbing";
    }
  });
  element.addEventListener(
    "pointerup",
    action(async (event) => {
      const active = gesture?.active;
      gesture = null;
      element.style.cursor = "";
      if (!active) return;
      element.dataset.dragged = "true";
      if (
        event.clientX >= 0 &&
        event.clientX < innerWidth &&
        event.clientY >= 0 &&
        event.clientY < innerHeight
      )
        return;
      await command("drag.drop", { path: assetPath(), selection });
    }),
  );
  element.addEventListener("pointercancel", () => {
    gesture = null;
    element.style.cursor = "";
  });
}

const thumbnailCache = new Map();
function thumbnail(path) {
  if (!thumbnailCache.has(path)) {
    const pending = host.artworkUrl(path).catch(() => null);
    thumbnailCache.set(path, pending);
    if (thumbnailCache.size > 64) {
      const oldest = thumbnailCache.keys().next().value;
      thumbnailCache.get(oldest).then((url) => {
        if (url) URL.revokeObjectURL(url);
      });
      thumbnailCache.delete(oldest);
    }
  }
  return thumbnailCache.get(path);
}

function renderRows() {
  if (!page) return;
  const fragment = document.createDocumentFragment();
  const waveCanvases = [];
  for (const asset of page.items) {
    const selected = asset.selected || snapshot?.selected?.path === asset.path;
    const row = node("div", `result-row${selected ? " selected" : ""}`);
    row.dataset.path = asset.path;
    const appearance = snapshot?.rowAppearance;
    row.classList.toggle(
      "played",
      Boolean(asset.played && appearance?.textEnabled),
    );
    row.style.setProperty("--played-text", appearance?.text || "#F0C85A");
    row.classList.toggle("marked", Boolean(asset.marked));
    row.setAttribute("role", "row");
    row.setAttribute("aria-selected", String(Boolean(selected)));
    row.title = `${asset.name}\n${asset.description || asset.path}`;
    attachArrangeDrag(row, () => asset.path, false);
    row.onclick = action((event) => {
      if (row.dataset.dragged) {
        delete row.dataset.dragged;
        return;
      }
      return selectAsset(asset, event);
    });
    row.ondblclick = action(() =>
      command("preview.play", {
        path: asset.path,
        position: 0,
        selection: false,
      }),
    );
    row.oncontextmenu = (event) => {
      event.preventDefault();
      rowMenu(event, asset);
    };
    row.onpointerdown = (event) => {
      if (event.altKey && event.button === 0)
        host?.dragFiles([asset.path]).catch(report);
    };
    for (const [key] of visibleColumns()) {
      const cell = node("div", `result-cell ${key}`);
      cell.dataset.column = key;
      cell.style.width = `${width(key)}px`;
      cell.setAttribute("role", "gridcell");
      if (key === "waveform") {
        const canvas = node("canvas");
        cell.append(canvas);
        const playhead = node("span", "mini-playhead");
        playhead.setAttribute("aria-hidden", "true");
        cell.append(playhead);
        waveCanvases.push([canvas, asset.waveform, selected, asset]);
        if (!asset.waveform && asset.waveError) {
          const retry = node("button", "mini-wave-retry", "重试波形");
          retry.onclick = action(async (event) => {
            event.stopPropagation();
            await command("waveform.get", {
              path: asset.path,
              points: 512,
              retry: true,
            });
            await requestPage();
            if (snapshot?.selected?.path === asset.path)
              await requestDetailWave();
          });
          cell.append(retry);
        }
        cell.onclick = action(async (event) => {
          event.stopPropagation();
          await selectAsset(asset, event, false);
          const rect = cell.getBoundingClientRect();
          await command("preview.play", {
            path: asset.path,
            position: clamp((event.clientX - rect.left) / rect.width, 0, 1),
            selection: false,
          });
        });
      } else if (key === "artwork_path") {
        if (
          snapshot?.artworkEnabled !== false &&
          asset.artwork_path &&
          asset.artwork_path !== "-"
        ) {
          const cover = node("img", "row-artwork");
          cover.alt = asset.library || "封面";
          cell.append(cover);
          thumbnail(asset.artwork_path).then((url) => {
            if (url && cover.isConnected) cover.src = url;
          });
        }
      } else if (key === "star") {
        cell.textContent = asset.favorite ? "★" : "☆";
        cell.classList.toggle("favorite", asset.favorite);
        cell.onclick = action(async (event) => {
          event.stopPropagation();
          await command("favorite.toggle", { path: asset.path });
          requestPage();
        });
      } else {
        const value =
          key === "index"
            ? asset.index
            : key === "duration"
              ? time(asset.duration)
              : key === "description"
                ? asset.description || asset.keywords || asset.path
                : asset[key];
        cell.append(node("span", null, value ?? ""));
        if (["description", "library", "channels"].includes(key))
          cell.classList.add("dim");
      }
      row.append(cell);
    }
    fragment.append(row);
  }
  $("visible-rows").style.transform =
    `translateY(${page.offset * prefs.rowHeight}px)`;
  $("visible-rows").replaceChildren(fragment);
  updateMiniPlayheads();
  requestAnimationFrame(() => {
    const color = getComputedStyle(document.body)
      .getPropertyValue("--text")
      .trim();
    for (const [canvas, wave, selected, asset] of waveCanvases) {
      const appearance = snapshot?.rowAppearance;
      let waveColor = appearance?.waveform || color;
      if (asset.played && appearance?.waveformEnabled)
        waveColor = appearance.played;
      if (asset.marked) waveColor = appearance?.marked || "#F0C85A";
      if (selected) waveColor = appearance?.selected || color;
      drawPeaks(canvas, wave, waveformInk(waveColor, color), selected);
    }
  });
}

function waveformInk(value, fallback) {
  // Default pale inks belong to the dark native palette. Keep explicit custom
  // colors, but use the paper theme's readable ink for those default values.
  if (
    prefs.theme === "paper" &&
    ["#d7d8da", "#eaf3ff", "#dce8f3", "#f5faff"].includes(value?.toLowerCase())
  )
    return fallback;
  return value || fallback;
}

function updateMiniPlayheads() {
  for (const row of $("visible-rows").children) {
    const playhead = row.querySelector(".mini-playhead");
    if (!playhead) continue;
    playhead.hidden =
      !snapshot?.playing || snapshot.previewPath !== row.dataset.path;
    playhead.style.left = `${clamp(snapshot?.position || 0, 0, 1) * 100}%`;
    playhead.style.background = snapshot?.rowAppearance?.playhead || "#cabb8a";
  }
}

async function selectAsset(asset, event = {}, autoPlay) {
  let result = await command("selection.set", {
    index: asset.index,
    path: asset.path,
    revision: page?.revision,
    ctrl: event.ctrlKey || event.metaKey || false,
    shift: event.shiftKey || false,
    autoPlay,
  });
  if (result?.stale) {
    await requestPage();
    const current = page?.items.find((item) => item.path === asset.path);
    if (!current) throw new Error("所选声音已离开当前结果，请重新选择");
    result = await command("selection.set", {
      index: current.index,
      path: current.path,
      revision: page.revision,
      ctrl: event.ctrlKey || event.metaKey || false,
      shift: event.shiftKey || false,
      autoPlay,
    });
    if (result?.stale) throw new Error("列表仍在更新，请稍后选择");
  }
  await requestPage();
}

function requestPage(force = true) {
  if (!host || !snapshot || snapshot.startup) return Promise.resolve();
  if (pageTask) {
    pageRequestAgain = true;
    return pageTask;
  }
  pageTask = (async () => {
    do {
      pageRequestAgain = false;
      const sequence = pageSequence;
      const scroll = $("result-scroll");
      const offset = Math.max(
        0,
        Math.floor(scroll.scrollTop / prefs.rowHeight) - 6,
      );
      const limit = Math.max(
        1,
        Math.min(100, Math.ceil(scroll.clientHeight / prefs.rowHeight) + 18),
      );
      const key = [
        snapshot.revision,
        snapshot.activeTab,
        offset,
        limit,
        prefs.columns.waveform,
      ].join(":");
      if (!force && key === lastPageKey) break;
      try {
        const result = await command("catalog.page", {
          offset,
          limit,
          waveforms: prefs.columns.waveform,
        });
        if (sequence !== pageSequence) {
          pageRequestAgain = true;
          continue;
        }
        if (snapshot?.startup) break;
        lastPageKey = key;
        page = result;
        scroll.setAttribute("aria-rowcount", result.total);
        $("result-space").style.height = `${result.total * prefs.rowHeight}px`;
        const content = JSON.stringify(result);
        if (content !== lastPageContent) {
          lastPageContent = content;
          renderRows();
        }
        clearTimeout(pageRetry);
        if (
          prefs.columns.waveform &&
          result.items.some((asset) => !asset.waveform && !asset.waveError)
        )
          pageRetry = setTimeout(() => requestPage(), 850);
      } catch (error) {
        report(error);
        break;
      }
      force = true;
    } while (pageRequestAgain);
  })().finally(() => {
    pageTask = null;
  });
  return pageTask;
}

function navItem(label, callback, active, className = "") {
  const button = node(
    "button",
    `nav-item ${className}${active ? " active" : ""}`,
  );
  button.append(node("span", null, label));
  button.onclick = action(callback);
  return button;
}

function query(params) {
  $("result-scroll").scrollTop = 0;
  pageSequence++;
  return command("catalog.query", {
    search: $("search").value,
    view: "all",
    ...params,
  });
}

const navigationTitles = {
  libraries: "音效库与文件夹",
  all: "浏览与筛选",
  favorites: "收藏与保存的搜索",
  previewed: "试听历史",
  ucs: "UCS 分类",
  collections: "集合与素材箱",
};
function updateNavigation() {
  const mode = navigationTitles[prefs.navigationPanel]
    ? prefs.navigationPanel
    : "libraries";
  prefs.navigationPanel = mode;
  if ($("source-title").textContent !== navigationTitles[mode])
    $("source-title").textContent = navigationTitles[mode];
  for (const panel of document.querySelectorAll("[data-source-panel]"))
    panel.hidden = !panel.dataset.sourcePanel.split(" ").includes(mode);
  for (const button of document.querySelectorAll("[data-rail]")) {
    const selected = button.dataset.rail === mode;
    button.classList.toggle("active", selected);
    if (button.getAttribute("aria-pressed") !== String(selected))
      button.setAttribute("aria-pressed", String(selected));
  }
}

function openNavigation(mode) {
  prefs.navigationPanel = mode;
  prefs.left = true;
  if (snapshot) renderSidebar();
  applyPreferences();
  persist();
  $("sources").scrollTop = 0;
  if (mode === "ucs") $("ucs-directory").open = true;
}

function folderBranch(root, folder = root) {
  const branch = node("details", "folder-branch");
  const summary = node("summary", "folder-row");
  branch.dataset.path = folder.path;
  branch.open = folderOpen.has(folder.path);
  const toggle = node("button", "folder-toggle");
  let expandable = folder.children !== false;
  const updateIcon = () => {
    toggle.replaceChildren(
      icon(branch.open && expandable ? "folderOpen" : "folder"),
    );
    toggle.setAttribute(
      "aria-label",
      `${expandable ? (branch.open ? "收起文件夹" : "展开文件夹") : "打开文件夹"} ${folder.name || folder.path}`,
    );
    if (expandable) toggle.setAttribute("aria-expanded", String(branch.open));
    else toggle.removeAttribute("aria-expanded");
  };
  updateIcon();
  toggle.onclick = (event) => {
    event.preventDefault();
    event.stopPropagation();
    if (expandable) branch.open = !branch.open;
    else label.click();
  };
  const label = node("button", "nav-item");
  label.append(
    node(
      "span",
      null,
      folder.name || folder.path.split(/[\\/]/).filter(Boolean).pop(),
    ),
  );
  label.onclick = action((event) => {
    event.preventDefault();
    event.stopPropagation();
    return query({ libraryId: root.libraryId, root: folder.path });
  });
  label.dataset.literal = "true";
  label.classList.toggle("active", snapshot?.root === folder.path);
  label.oncontextmenu = (event) => {
    event.preventDefault();
    if (folder === root)
      managementMenu(event, "root", { ...root, name: root.path });
    else
      menu(pointerAnchor(event), [
        [
          "打开文件夹",
          () =>
            command("management.action", {
              kind: "root",
              id: root.id,
              action: "open",
              path: folder.path,
            }),
        ],
        [
          branch.open ? "折叠此层级" : "展开此层级",
          () => {
            branch.open = !branch.open;
          },
          "",
          expandable,
        ],
      ]);
  };
  label.ondblclick = (event) => {
    event.preventDefault();
    if (expandable) branch.open = !branch.open;
  };
  label.title = folder.path;
  if (folder.count !== undefined)
    label.append(node("small", "folder-count", folder.count));
  summary.onclick = (event) => event.preventDefault();
  summary.append(toggle, label);
  branch.append(summary);
  let loaded = folder.children === false;
  let loading = false;
  let retry;
  const message = node("div", "folder-state");
  const load = async (offset = 0) => {
    if (loading || !branch.open || !branch.isConnected) return;
    loading = true;
    message.textContent = "正在读取文件夹…";
    branch.append(message);
    try {
      const result = await command("catalog.folders", {
        rootId: root.id,
        path: folder.path,
        offset,
      });
      if (!branch.isConnected || !branch.open) return;
      if (result.pending) {
        message.textContent = "正在整理文件夹索引…";
        retry = setTimeout(() => {
          if (branch.isConnected && branch.open) load(offset).catch(report);
        }, 650);
        return;
      }
      loaded = true;
      message.remove();
      for (const child of result.items)
        branch.append(folderBranch(root, child));
      if (offset + result.items.length < result.total) {
        const more = node("button", "nav-item", "更多文件夹…");
        more.onclick = action(async () => {
          more.remove();
          await load(offset + result.items.length);
        });
        branch.append(more);
      }
      if (!offset && !result.total) {
        expandable = false;
        updateIcon();
        message.textContent = "此文件夹没有已索引的子文件夹";
        branch.append(message);
      }
    } catch (error) {
      message.textContent = error.message;
      const retryButton = node("button", null, "重试");
      retryButton.onclick = action(() => load(offset));
      message.append(retryButton);
    } finally {
      loading = false;
    }
  };
  branch.ontoggle = action(() => {
    updateIcon();
    if (branch.open) folderOpen.add(folder.path);
    else {
      folderOpen.delete(folder.path);
      clearTimeout(retry);
    }
    if (branch.open && !loaded) return load();
  });
  return branch;
}

function renderSidebar() {
  const views = [
    ["all", "全部声音"],
    ["favorites", "收藏"],
    ["recent", "最近插入"],
    ["previewed", "试听历史"],
    ["project_used", "当前工程"],
    ["ucs_pending", "UCS 待确认"],
    ["missing", "缺失素材"],
    ["duplicates", "重复检查"],
  ];
  $("views").replaceChildren(
    ...views
      .filter(([view]) =>
        prefs.navigationPanel === "favorites"
          ? view === "favorites"
          : prefs.navigationPanel === "previewed"
            ? ["previewed", "recent"].includes(view)
            : true,
      )
      .map(([view, label]) =>
        navItem(
          label,
          () => query({ view }),
          snapshot.view === view &&
            !snapshot.libraryId &&
            !snapshot.collectionId,
        ),
      ),
  );
  const libraries = [];
  for (const library of snapshot.libraries) {
    const collapsed = prefs.collapsedLibraries?.includes(library.id);
    libraries.push(
      navItem(
        library.name,
        () => query({ libraryId: library.id }),
        snapshot.libraryId === library.id,
      ),
    );
    libraries[libraries.length - 1].dataset.libraryId = library.id;
    libraries[libraries.length - 1].prepend(
      icon(collapsed ? "folder" : "folderOpen"),
    );
    libraries[libraries.length - 1].dataset.literal = "true";
    libraries[libraries.length - 1].oncontextmenu = (event) => {
      event.preventDefault();
      managementMenu(event, "library", library);
    };
    for (const root of snapshot.roots.filter(
      (root) => root.libraryId === library.id && root.enabled !== false,
    )) {
      if (!collapsed && prefs.navigation?.folders !== false)
        libraries.push(folderBranch(root));
    }
  }
  $("libraries").replaceChildren(...libraries);
  $("collections").replaceChildren(
    ...snapshot.collections.map((collection) => {
      const item = navItem(
        collection.name,
        () => query({ collectionId: collection.id }),
        snapshot.collectionId === collection.id,
      );
      item.oncontextmenu = (event) => {
        event.preventDefault();
        managementMenu(event, "collection", collection);
      };
      item.append(node("small", null, collection.count));
      return item;
    }),
  );
  if (!snapshot.collections.length)
    $("collections").append(
      node("p", "sidebar-empty", "新建集合，将常用声音整理到一起。"),
    );
  $("saved-searches").replaceChildren(
    ...(snapshot.savedSearches || []).map((saved) => {
      const item = navItem(
        saved.name,
        () =>
          command("management.action", {
            kind: "search",
            id: saved.id,
            action: "activate",
          }),
        false,
      );
      item.oncontextmenu = (event) => {
        event.preventDefault();
        managementMenu(event, "search", saved);
      };
      return item;
    }),
  );
  for (const [id, key] of [
    ["libraries", "libraries"],
    ["collections", "collections"],
    ["ucs-directory", "ucs"],
    ["saved-searches", "saved"],
    ["workflow-filters", "workflow"],
  ]) {
    const item = $(id);
    const target = item.closest("details") || item;
    target.hidden = prefs.navigation?.[key] === false;
    if (item.previousElementSibling?.classList.contains("section-label"))
      item.previousElementSibling.hidden = target.hidden;
  }
  $("workflow-filters").replaceChildren(
    ...[
      { id: "", label: "全部状态" },
      ...(snapshot.workflowStatuses || []),
    ].map((status) =>
      navItem(
        status.label,
        () => command("catalog.query", { keepScope: true, status: status.id }),
        (snapshot.statusFilter || "") === status.id,
      ),
    ),
  );
  $("scope").replaceChildren(
    new Option("全部音效库", ""),
    ...snapshot.libraries.map(
      (library) => new Option(library.name, library.id),
    ),
  );
  $("scope").value = snapshot.libraryId || "";
}

function renderTabs() {
  $("tabs").replaceChildren(
    ...snapshot.tabs.map((tab) => {
      const button = node(
        "button",
        tab.id === snapshot.activeTab ? "active" : "",
        tab.name,
      );
      button.onclick = action(() =>
        command("tab.action", { action: "activate", id: tab.id }),
      );
      button.oncontextmenu = (event) => {
        event.preventDefault();
        const entries = [
          ["复制标签", { action: "new", duplicateId: tab.id }],
          ["重命名", { action: "rename", id: tab.id }],
          ["左移", { action: "move", id: tab.id, direction: -1 }],
          ["右移", { action: "move", id: tab.id, direction: 1 }],
          ["关闭其他标签", { action: "close", id: tab.id, mode: "others" }],
          ["关闭右侧标签", { action: "close", id: tab.id, mode: "right" }],
        ].map(([label, params]) => [
          label,
          async () => {
            if (params.action === "rename") {
              params.name = await promptName("重命名标签页", tab.name);
              if (params.name === null) return;
            }
            await command("tab.action", params);
          },
        ]);
        menu(pointerAnchor(event), entries);
      };
      if (snapshot.tabs.length > 1) {
        const close = node("span", "tab-close", "×");
        close.onclick = action((event) => {
          event.stopPropagation();
          return command("tab.action", { action: "close", id: tab.id });
        });
        button.append(close);
      }
      return button;
    }),
  );
}

function applySnapshot(next) {
  const previous = snapshot;
  if (previous && previous.activeTab !== next.activeTab) {
    tabScroll.set(previous.activeTab, {
      top: $("result-scroll").scrollTop,
      left: $("result-scroll").scrollLeft,
      zoomStart,
      zoomEnd,
    });
    pageSequence++;
  }
  snapshot = next;
  $("performance-stats").hidden = !next.performance;
  if (next.performance)
    $("performance-stats").textContent =
      `Lua ${next.performance.background.toFixed(1)} ms · UI ${next.performance.update.toFixed(1)} ms · Δ ${next.performance.interval.toFixed(1)} ms`;
  settings.update(next);
  updateTransferStatus();
  if (next.language && next.language !== prefs.language) {
    prefs.language = next.language;
    localizer.setLanguage(next.language);
    persist();
    if (ucsCatalog) renderUcs();
  }
  const ready = !next.startup;
  if (next.sortMode) $("sort").value = next.sortMode;
  if (next.sortDescending !== undefined) {
    sortDescending = next.sortDescending;
    $("sort-direction").textContent = sortDescending ? "↓" : "↑";
  }
  $("result-count").textContent = next.startup
    ? next.startup.phase
    : `${next.count.toLocaleString()} 个结果${next.pending ? " · 更新中" : ""}`;
  $("selection-count").textContent = next.selectedCount;
  $("status").textContent = next.startup?.failure || next.status || "就绪";
  $("status").classList.toggle(
    "error",
    Boolean(next.error || next.startup?.failure),
  );
  $("empty-state").hidden = !ready || next.loaded > 0;
  $("no-results").hidden =
    !ready || !next.loaded || next.count > 0 || next.pending;
  $("startup-state").hidden = ready;
  $("startup-phase").textContent =
    next.startup?.failure || next.startup?.phase || "";
  $("startup-count").textContent = next.startup
    ? `${next.loaded.toLocaleString()} 个素材`
    : "";
  for (const id of [
    "play",
    "stop",
    "insert",
    "save-region",
    "similar-search",
    "drag-selection",
  ])
    $(id).disabled = !ready || !next.selected;
  $("ai-search").disabled = !ready;
  $("ai-search").title = next.tasks?.ai ? "取消 AI 搜索" : "AI 语义搜索";
  renderFilterBar();
  updateNavigation();
  $("ai-more").hidden = next.view !== "ai_semantic" || !next.aiHasMore;
  const tasks = Object.entries(next.tasks)
    .filter(([, running]) => running)
    .map(
      ([name]) =>
        ({
          scan: "扫描",
          import: "导入",
          transfer: "交付",
          similar: "相似检索",
          ai: "AI 搜索",
          precache: "波形预生成",
          classify: "分类",
          relink: "重新链接",
          remove: "移除来源",
          verify: "缓存校验",
          missing: "缺失检查",
          duplicates: "重复检查",
          transients: "瞬态检测",
          loudness: "响度分析",
        })[name],
    );
  $("tasks-label").textContent = tasks.join(" · ");
  $("tasks-label").title = next.aiSummary || "";
  if (next.transferProgress)
    $("tasks-label").textContent +=
      ` ${next.transferProgress.completed}/${next.transferProgress.total}`;
  $("cancel-tasks").hidden = tasks.length === 0;
  $("play").setAttribute("aria-pressed", String(next.playing));
  $("loop").setAttribute("aria-pressed", String(next.fx.loop));
  if (next.autoPreview !== undefined)
    $("auto-preview").checked = next.autoPreview;
  $("scope-label").textContent = next.readOnly ? "只读保护" : "";
  const sideKey = JSON.stringify([
    next.libraries,
    next.collections,
    next.roots,
    next.libraryId,
    next.collectionId,
    next.view,
    next.savedSearches,
    next.statusFilter,
    next.root,
    next.language,
  ]);
  if (sideKey !== sidebarSignature) {
    sidebarSignature = sideKey;
    renderSidebar();
  }
  const tabKey = JSON.stringify([next.tabs, next.activeTab]);
  if (tabKey !== tabsSignature) {
    tabsSignature = tabKey;
    renderTabs();
  }
  if (
    document.activeElement !== $("search") &&
    (previous?.search !== next.search || previous?.activeTab !== next.activeTab)
  )
    $("search").value = next.search;
  if (
    ready &&
    (!previous || previous.startup || previous.revision !== next.revision)
  )
    requestPage();
  if (previous && previous.activeTab !== next.activeTab) {
    const position = tabScroll.get(next.activeTab) || { top: 0, left: 0 };
    $("result-space").style.height = `${next.count * prefs.rowHeight}px`;
    $("result-scroll").scrollTop = position.top;
    $("result-scroll").scrollLeft = position.left;
    requestPage();
  }
  if (!previous || previous?.selected?.path !== next.selected?.path) {
    if (previous?.selected?.path && Object.keys(dirtyFields).length) {
      metadataDrafts.set(previous.selected.path, {
        dirtyFields,
        originalFields,
      });
    }
    detailWave = null;
    waveFailure = "";
    zoomStart = 0;
    zoomEnd = 1;
    const savedDraft = metadataDrafts.get(next.selected?.path);
    dirtyFields = savedDraft?.dirtyFields || {};
    originalFields = savedDraft?.originalFields || {};
    if (inspectorTab !== "transfer") renderInspector();
    requestDetailWave();
    requestPage();
  } else if (
    next.selected &&
    inspectorTab !== "transfer" &&
    !$("inspector-body").contains(document.activeElement) &&
    !Object.keys(dirtyFields).length &&
    JSON.stringify(previous?.selected) !== JSON.stringify(next.selected)
  ) {
    renderInspector();
  }
  if (
    previous?.spectralPeaks !== next.spectralPeaks ||
    previous?.detailPoints !== next.detailPoints ||
    previous?.multichannelWaveform !== next.multichannelWaveform
  )
    requestDetailWave();
  if (
    previous?.selectedCount !== next.selectedCount &&
    inspectorTab !== "transfer"
  )
    renderInspector();
  if (
    JSON.stringify(previous?.rowAppearance) !==
      JSON.stringify(next.rowAppearance) ||
    previous?.artworkEnabled !== next.artworkEnabled
  )
    renderRows();
  if (
    previous?.selectionRevision !== next.selectionRevision ||
    previous?.selectedCount !== next.selectedCount ||
    previous?.playedCount !== next.playedCount
  )
    requestPage();
  $("asset-name").textContent = next.selected?.name || "选择一个声音";
  $("asset-info").textContent = next.selected
    ? `${next.selected.channels} ch · ${Math.round(next.selected.sampleRate / 1000)} kHz · ${next.selected.bitDepth} bit · ${next.selected.library}`
    : "";
  renderLoudness();
  renderSimilarityProgress();
  for (const [key, field] of [
    ["pitch", "pitch"],
    ["rate", "rate"],
    ["gain", "gain_db"],
  ]) {
    if (!$("fx-panel").contains(document.activeElement)) {
      $(`fx-${key}`).value = next.fx[field];
      $(`fx-${key}-value`).value = next.fx[field];
    }
  }
  $("preserve-pitch").checked = next.fx.preserve_pitch;
  $("reverse").checked = next.fx.reverse;
  updateReadouts();
  updateMiniPlayheads();
  renderClassificationReview();
  drawDetail();
}

async function requestDetailWave(retry = false) {
  const selected = snapshot?.selected;
  const sequence = ++waveSequence;
  clearTimeout(waveRetry);
  if (!selected) {
    drawDetail();
    return;
  }
  try {
    const result = await command("waveform.get", {
      path: selected.path,
      points: snapshot?.detailPoints >= 4096 ? 4096 : 2048,
      retry: retry === true,
    });
    if (sequence !== waveSequence || snapshot?.selected?.path !== result.path)
      return;
    detailWave = result.waveform;
    waveFailure = result.error || "";
    drawDetail();
    if (!detailWave && !waveFailure)
      waveRetry = setTimeout(requestDetailWave, 850);
  } catch (error) {
    if (sequence !== waveSequence) return;
    waveFailure = error.message || String(error);
    drawDetail();
    report(error);
  }
}

let loudnessKey;
let similarityProgressKey;
function renderLoudness() {
  const asset = snapshot?.selected;
  const strip = $("loudness-strip");
  strip.hidden = !asset;
  const key = JSON.stringify([
    asset?.path,
    asset?.loudness,
    asset?.loudnessEnabled,
  ]);
  if (key === loudnessKey) return;
  loudnessKey = key;
  const heading = node("span", "loudness-heading", "响度");
  const content = [heading];
  for (const item of asset?.loudness || []) {
    const metric = node("span", "loudness-metric");
    const label =
      { M: "LUFS-M", S: "LUFS-S", TP: "True Peak", LOUDNESS: "响度" }[
        item.label
      ] || item.label;
    metric.append(node("span", null, label), node("strong", null, item.value));
    metric.title =
      {
        "LUFS-I": "综合响度",
        M: "最大瞬时响度",
        S: "最大短时响度",
        TP: "真峰值",
      }[item.label] || label;
    content.push(metric);
  }
  if (!asset?.loudness?.length)
    content.push(
      node(
        "span",
        "muted",
        asset?.loudnessEnabled === false ? "响度显示已关闭" : "尚无响度数据",
      ),
    );
  const analyze = node(
    "button",
    "loudness-analyze",
    asset?.loudnessEnabled === false ? "启用并分析" : "重新分析",
  );
  analyze.onclick = action(async () => {
    if (snapshot?.selected?.loudnessEnabled === false)
      await command("settings.update", {
        values: { show_loudness_metrics: true },
      });
    await command("asset.action", { action: "loudness" });
  });
  content.push(analyze);
  strip.replaceChildren(...content);
}

function renderSimilarityProgress() {
  const progress = snapshot?.similarityProgress;
  $("analysis-bar").hidden = !progress && !snapshot?.tasks?.similar;
  layoutAudition();
  $("similar-search").disabled ||= Boolean(snapshot?.tasks?.similar);
  const key = JSON.stringify(progress);
  if (key === similarityProgressKey) return;
  similarityProgressKey = key;
  if (!progress) return;
  const phase =
    {
      prepare: "准备分析",
      load_cache: "读取特征缓存",
      reference: "分析参考声音",
      index_candidates: "整理候选声音",
      neural_prepare: "准备神经分析",
      neural_manifest: "准备索引清单",
      neural_wait: "等待后台分析",
      "building-cache": "建立声音特征缓存",
      "building-index": "建立相似索引",
      "querying-hnsw": "检索相似声音",
      "querying-exact": "检索相似声音",
      "querying-exact-filtered": "检索当前范围",
      neural_rerank: "整理相似结果",
      analyze_missing: "分析候选声音",
      rank_buckets: "整理相似结果",
    }[progress.phase] || "分析声音";
  $("analysis-label").textContent = `相似声音 · ${phase}`;
  $("analysis-label").title = progress.failure
    ? `已切换为音频特征分析：${progress.failure}`
    : progress.reference || "";
  const total = Math.max(0, Number(progress.total) || 0);
  const completed = Math.max(0, Number(progress.completed) || 0);
  $("analysis-count").textContent = total
    ? `${completed.toLocaleString()} / ${total.toLocaleString()}`
    : "准备中…";
  $("analysis-progress").max = Math.max(1, total);
  if (total && completed) $("analysis-progress").value = completed;
  else $("analysis-progress").removeAttribute("value");
}

function updateReadouts() {
  const duration = snapshot?.selected?.duration || 0;
  const start = regionDrag
    ? Math.min(regionDrag.start, regionDrag.current)
    : snapshot?.regionStart || 0;
  const end = regionDrag
    ? Math.max(regionDrag.start, regionDrag.current)
    : (snapshot?.regionEnd ?? 1);
  $("current-time").textContent = time((snapshot?.position || 0) * duration);
  $("in-time").textContent = time(start * duration);
  $("out-time").textContent = time(end * duration);
  $("range-time").textContent = time((end - start) * duration);
  $("transport-time").textContent =
    `${time((snapshot?.position || 0) * duration)} / ${time(duration)}`;
  $("range-label").textContent = duration
    ? `${time(start * duration)} — ${time(end * duration)}`
    : "";
}

function drawDetail() {
  const position =
    ((snapshot?.position || 0) - zoomStart) / (zoomEnd - zoomStart);
  const playhead = $("detail-playhead");
  playhead.hidden = !snapshot?.selected || position < 0 || position > 1;
  playhead.style.left = `${position * 100}%`;
  playhead.style.background = snapshot?.rowAppearance?.playhead || "#b8d6c3";
  const canvas = $("detail-wave");
  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  const ratio = Math.min(devicePixelRatio || 1, 2);
  const paintKey = JSON.stringify([
    rect.width,
    rect.height,
    ratio,
    zoomStart,
    zoomEnd,
    snapshot?.selected?.path,
    snapshot?.selected?.duration,
    snapshot?.selected?.regions,
    snapshot?.regionStart,
    snapshot?.regionEnd,
    regionDrag?.start,
    regionDrag?.current,
    waveFailure,
    prefs.theme,
    prefs.accentColor,
    prefs.waveformColorMode,
    prefs.waveformSelectionColor,
    snapshot?.rowAppearance,
    snapshot?.multichannelWaveform,
  ]);
  if (detailPaintKey === paintKey && detailPaintWave === detailWave) return;
  detailPaintKey = paintKey;
  detailPaintWave = detailWave;
  canvas.width = Math.round(rect.width * ratio);
  canvas.height = Math.round(rect.height * ratio);
  const context = canvas.getContext("2d");
  context.scale(ratio, ratio);
  const palette = getComputedStyle(document.body);
  const color = waveformInk(
    snapshot?.rowAppearance?.waveform,
    palette.getPropertyValue("--text").trim(),
  );
  const muted = palette.getPropertyValue("--muted").trim();
  const accent =
    prefs.waveformColorMode === "custom"
      ? prefs.waveformSelectionColor || defaults.waveformSelectionColor
      : palette.getPropertyValue("--accent").trim();
  const duration = snapshot?.selected?.duration || 0;
  $("wave-status").hidden = Boolean(detailWave);
  $("wave-retry").hidden = !waveFailure || !snapshot?.selected;
  $("wave-status").textContent = snapshot?.selected
    ? waveFailure || "正在读取波形缓存…"
    : "等待选择素材";
  if (!duration) return;
  const top = 26;
  const xFor = (percent) =>
    ((percent - zoomStart) / (zoomEnd - zoomStart)) * rect.width;
  const start = regionDrag
    ? Math.min(regionDrag.start, regionDrag.current)
    : snapshot.regionStart;
  const end = regionDrag
    ? Math.max(regionDrag.start, regionDrag.current)
    : snapshot.regionEnd;
  for (const region of snapshot?.selected?.regions || []) {
    context.fillStyle = snapshot?.rowAppearance?.region || accent;
    context.globalAlpha = 0.1;
    context.fillRect(
      xFor(region.start),
      top,
      xFor(region.finish) - xFor(region.start),
      rect.height - top,
    );
  }
  // The default full-file range has a neutral background; only a deliberate
  // partial selection receives the theme tint.
  context.fillStyle = accent;
  context.globalAlpha = 0.12;
  if (start > 0 || end < 1)
    context.fillRect(
      xFor(start),
      top,
      xFor(end) - xFor(start),
      rect.height - top,
    );
  context.globalAlpha = 1;
  context.font = '10px "Segoe UI",sans-serif';
  context.fillStyle = muted;
  context.strokeStyle = palette.getPropertyValue("--line").trim();
  const ticks = Math.max(3, Math.floor(rect.width / 100));
  for (let i = 0; i <= ticks; i++) {
    const x = (i / ticks) * rect.width;
    context.textAlign = i === 0 ? "left" : i === ticks ? "right" : "center";
    context.fillText(
      ((zoomStart + (i / ticks) * (zoomEnd - zoomStart)) * duration).toFixed(3),
      x,
      13,
    );
    context.beginPath();
    context.moveTo(x, 20);
    context.lineTo(x, rect.height);
    context.globalAlpha = 0.35;
    context.stroke();
    context.globalAlpha = 1;
  }
  const channels =
    snapshot?.multichannelWaveform !== false && detailWave?.channels?.length
      ? detailWave.channels
      : detailWave
        ? [detailWave.peaks]
        : [];
  const laneHeight = (rect.height - top) / Math.max(1, channels.length);
  for (let channel = 0; channel < channels.length; channel++) {
    const values = channels[channel];
    const center = top + laneHeight * (channel + 0.5);
    context.strokeStyle = color;
    context.beginPath();
    for (let x = 0; x < rect.width; x++) {
      const first = Math.floor(
        (zoomStart + (x / rect.width) * (zoomEnd - zoomStart)) * values.length,
      );
      const last = Math.max(
        first + 1,
        Math.ceil(
          (zoomStart + ((x + 1) / rect.width) * (zoomEnd - zoomStart)) *
            values.length,
        ),
      );
      let peak = 0;
      for (let i = first; i < last; i++)
        peak = Math.max(peak, Math.abs(values[i] || 0));
      if (detailWave?.spectralFrequency?.length) {
        context.stroke();
        context.beginPath();
        context.strokeStyle = spectralColor(detailWave, first, color);
      }
      const height = Math.max(0.3, Math.min(1, peak) * (laneHeight / 2 - 9));
      context.moveTo(x + 0.5, center - height);
      context.lineTo(x + 0.5, center + height);
    }
    context.stroke();
    context.textAlign = "left";
    context.fillStyle = muted;
    context.fillText(
      channels.length === 2 ? ["L", "R"][channel] : `Ch ${channel + 1}`,
      4,
      top + channel * laneHeight + 13,
    );
  }
  context.strokeStyle = accent;
  for (const point of [start, end]) {
    context.beginPath();
    context.moveTo(xFor(point), top);
    context.lineTo(xFor(point), rect.height);
    context.stroke();
  }
}

function field(label, key, value, multiline = false) {
  const wrapper = node("label", "field");
  wrapper.append(node("span", null, label));
  const input = node(multiline ? "textarea" : "input");
  input.value = value || "";
  input.dataset.field = key;
  wrapper.append(input);
  return [wrapper, input];
}

async function renderBulkMetadata(container) {
  const selection = await command("metadata.selection");
  if (!container.isConnected) return;
  container.append(node("h3", null, `编辑 ${selection.count} 个素材`));
  container.append(node("p", "muted", "仅将勾选的字段应用到全部所选素材。"));
  const inputs = [];
  for (const definition of selection.fields) {
    const [wrapper, input] = field(
      definition.label,
      definition.key,
      selection.values[definition.key],
      true,
    );
    const enabled = node("input");
    enabled.type = "checkbox";
    enabled.setAttribute("aria-label", `应用 ${definition.label}`);
    if (selection.truncated?.[definition.key]) {
      input.readOnly = true;
      enabled.disabled = true;
      input.title = "字段过长，当前仅显示摘要。";
    }
    if (selection.mixed[definition.key]) input.placeholder = "多个不同值";
    input.oninput = () => {
      enabled.checked = true;
      dirtyFields[definition.key] = input.value;
    };
    enabled.onchange = () => {
      if (enabled.checked) dirtyFields[definition.key] = input.value;
      else delete dirtyFields[definition.key];
    };
    wrapper.prepend(enabled);
    container.append(wrapper);
    inputs.push({ key: definition.key, input, enabled });
  }
  const save = node("button", null, "应用到所选素材");
  save.onclick = action(async () => {
    const values = {};
    for (const item of inputs)
      if (item.enabled.checked) values[item.key] = item.input.value;
    await command("metadata.batch", {
      token: selection.token,
      count: selection.count,
      values,
    });
    dirtyFields = {};
    renderInspector();
  });
  container.append(save);
}

function renderInspector() {
  if (artworkUrl) {
    URL.revokeObjectURL(artworkUrl);
    artworkUrl = null;
  }
  const container = node("div", "inspector-content");
  const selected = snapshot?.selected;
  const expanded = fullMetadata.get(selected?.path);
  const asset = expanded ? { ...selected, ...expanded } : selected;
  if (selected && Object.keys(selected.truncated || {}).length && !expanded) {
    command("metadata.get", { path: selected.path })
      .then((result) => {
        fullMetadata.set(selected.path, result);
        if (fullMetadata.size > 16)
          fullMetadata.delete(fullMetadata.keys().next().value);
        if (
          snapshot?.selected?.path === selected.path &&
          !Object.keys(dirtyFields).length
        )
          renderInspector();
      })
      .catch(report);
  }
  if (!asset && inspectorTab !== "transfer") {
    container.append(node("p", "muted", "选择声音以查看详情"));
    $("inspector-body").replaceChildren(container);
    return;
  }
  if (inspectorTab === "transfer") {
    $("inspector-body").replaceChildren(container);
    renderTransfer(container).catch(report);
    return;
  }
  if (inspectorTab === "metadata" && snapshot.selectedCount > 1) {
    $("inspector-body").replaceChildren(container);
    renderBulkMetadata(container).catch(report);
    return;
  }
  for (const candidate of asset.ucsCandidates || []) {
    const button = node(
      "button",
      null,
      `确认 UCS · ${candidate.catid} ${candidate.label}`,
    );
    button.onclick = action(() =>
      command("asset.action", {
        path: asset.path,
        action: "confirmUcs",
        catid: candidate.catid,
      }),
    );
    container.append(button);
  }

  container.append(node("h2", "selected-name", asset.name));
  if (asset.channels >= 1) {
    const channelControls = node("details", "settings-section");
    channelControls.append(node("summary", null, "试听声道"));
    if (asset.channels <= 2) {
      for (const [mode, label] of [
        ["original", "原声"],
        ["left", "左声道"],
        ["right", "右声道"],
        ["mono", "单声道"],
      ]) {
        if (asset.channels === 1 && (mode === "left" || mode === "right"))
          continue;
        const button = node("button", null, label);
        button.setAttribute(
          "aria-pressed",
          String((asset.channelMode || "original") === mode),
        );
        button.onclick = action(() =>
          command("asset.action", {
            path: asset.path,
            action: "channelMode",
            mode,
          }),
        );
        channelControls.append(button);
      }
    } else {
      const all = node("button", null, "全部");
      all.onclick = action(() =>
        command("asset.action", { action: "channelsAll" }),
      );
      channelControls.append(all);
      for (let channel = 1; channel <= Math.min(8, asset.channels); channel++) {
        const button = node("button", null, `Ch ${channel}`);
        button.setAttribute(
          "aria-pressed",
          String(asset.channelsSelected?.[channel - 1] === true),
        );
        button.onclick = action((event) =>
          command("asset.action", {
            action: "channel",
            channel,
            ctrl: event.ctrlKey,
            shift: event.shiftKey,
          }),
        );
        channelControls.append(button);
      }
    }
    container.append(channelControls);
  }
  if (inspectorTab === "metadata") {
    let cover;
    if (
      snapshot.artworkEnabled !== false &&
      asset.artwork_path &&
      asset.artwork_path !== "-"
    ) {
      const image = node("img", "artwork-cover");
      image.alt = asset.library || "音效库封面";
      image.hidden = true;
      cover = image;
      if (snapshot.artworkPinned !== false) container.append(image);
      host
        .artworkUrl(asset.artwork_path)
        .then((url) => {
          if (!url) return;
          if (!image.isConnected) {
            URL.revokeObjectURL(url);
            return;
          }
          artworkUrl = url;
          image.src = url;
          image.hidden = false;
        })
        .catch(() => {
          image.remove();
        });
    }
    const technical = node("dl", "technical");
    for (const [label, value] of [
      ["时长", time(asset.duration)],
      ["声道", asset.channels],
      ["采样率", `${asset.sampleRate} Hz`],
      ["位深", `${asset.bitDepth} bit`],
      ["音效库", asset.library],
      ["UCS 分类", asset.category],
      ["子类", asset.subcategory],
      ["CatID", asset.catid],
    ]) {
      technical.append(node("dt", null, label), node("dd", null, value || "—"));
    }
    container.append(technical);
    if (cover && snapshot.artworkPinned === false) container.append(cover);
    const previousOriginal = originalFields;
    originalFields = {};
    for (const [key, label, multiline] of [
      ["description", "描述", true],
      ["keywords", "关键词", true],
      ["category", "Category"],
      ["subcategory", "Subcategory"],
      ["catid", "CatID"],
      ["library", "Library"],
      ["artwork_path", "封面路径"],
    ]) {
      originalFields[key] =
        dirtyFields[key] !== undefined
          ? previousOriginal[key]
          : asset[key] || "";
      const [wrapper, input] = field(
        label,
        key,
        dirtyFields[key] ?? originalFields[key],
        multiline,
      );
      if (asset.truncated?.[key]) {
        input.readOnly = true;
        input.title =
          "此字段超过 64 KiB，当前显示摘要，已禁用覆盖以保留完整内容。";
      }
      input.oninput = () => {
        dirtyFields[key] = input.value;
      };
      if (!["artwork_path", "notes"].includes(key)) {
        const filter = node("button", "metadata-filter", "按此字段筛选");
        filter.type = "button";
        filter.disabled = !asset[key] || Boolean(asset.truncated?.[key]);
        filter.onclick = action(() =>
          command("asset.action", {
            path: asset.path,
            action: "filter",
            field: key,
          }),
        );
        wrapper.append(filter);
      }
      container.append(wrapper);
    }
    const save = node("button", null, "保存元数据");
    save.disabled = snapshot.readOnly;
    save.onclick = action(async () => {
      const saved = await command("metadata.save", {
        path: asset.path,
        original: originalFields,
        values: dirtyFields,
      });
      if (snapshot?.selected?.path === asset.path) {
        dirtyFields = {};
        metadataDrafts.delete(asset.path);
        fullMetadata.delete(asset.path);
        snapshot.selected = { ...snapshot.selected, ...saved };
        renderInspector();
      }
      requestPage();
    });
    const reveal = node("button", null, "显示文件");
    reveal.onclick = action(() => host.reveal(asset.path));
    const actions = node("div", "action-row");
    const artwork = node("button", null, "选择封面");
    artwork.onclick = () =>
      menu(artwork, [
        [
          "选择封面",
          () =>
            command("asset.action", { path: asset.path, action: "artwork" }),
        ],
        [
          "自动查找封面",
          () =>
            command("asset.action", {
              path: asset.path,
              action: "redetectArtwork",
            }),
        ],
        [
          "清除封面",
          () =>
            command("asset.action", {
              path: asset.path,
              action: "clearArtwork",
            }),
        ],
      ]);
    actions.append(save, reveal, artwork);
    container.append(actions, node("p", "path-label", asset.path));
  } else if (inspectorTab === "regions") {
    for (const [index, region] of (asset.regions || []).entries()) {
      const row = node("div", "region-row");
      const activate = node(
        "button",
        null,
        region.name || `Region ${index + 1}`,
      );
      activate.onclick = action(() =>
        command("region.action", { action: "activate", index: index + 1 }),
      );
      activate.ondblclick = action(() =>
        command("region.action", {
          action: "activate",
          index: index + 1,
          play: true,
        }),
      );
      const remove = node("button", null, "×");
      remove.onclick = action(() =>
        command("region.action", { action: "delete", index: index + 1 }),
      );
      row.append(
        activate,
        node(
          "small",
          null,
          time((region.finish - region.start) * asset.duration),
        ),
        remove,
      );
      container.append(row);
    }
    const add = node("button", null, "保存当前选区");
    add.onclick = action(saveRegion);
    container.append(add);
  } else {
    renderTransfer(container).catch(report);
  }
  $("inspector-body").replaceChildren(container);
}

async function renderTransfer(container) {
  const settings = await command("settings.get");
  if (inspectorTab !== "transfer" || !container.isConnected) return;
  const controls = {};
  container.append(
    node("h2", null, "Transfer 交付"),
    node("p", "muted", "选择输出方式，导出时应用当前 FX 与波形选区。"),
  );
  for (const [key, label] of [
    ["transfer_dir", "输出目录"],
    ["transfer_template", "文件名模板"],
  ]) {
    const [wrapper, input] = field(
      label,
      key,
      transferDraft[key] ?? settings[key],
    );
    input.oninput = () => {
      transferDraft[key] = input.value;
    };
    controls[key] = input;
    container.append(wrapper);
  }
  for (const [key, label, options] of [
    [
      "transfer_format",
      "格式",
      [
        ["wav24", "WAV 24 bit"],
        ["wav16", "WAV 16 bit"],
        ["wav32", "WAV 32 bit PCM"],
        ["flac", "FLAC"],
      ],
    ],
    [
      "transfer_sample_rate",
      "采样率",
      [
        ["source", "跟随源文件"],
        ["44100", "44.1 kHz"],
        ["48000", "48 kHz"],
        ["96000", "96 kHz"],
        ["192000", "192 kHz"],
      ],
    ],
    [
      "transfer_channels",
      "声道",
      [
        ["source", "跟随源文件"],
        ["mono", "Mono"],
        ["stereo", "Stereo"],
      ],
    ],
    [
      "transfer_scope",
      "范围",
      [
        ["selection", "当前选区"],
        ["full", "完整文件"],
      ],
    ],
  ]) {
    const wrapper = node("label", "field");
    wrapper.append(node("span", null, label));
    const select = node("select");
    select.append(...options.map(([value, title]) => new Option(title, value)));
    select.value = transferDraft[key] ?? settings[key];
    select.onchange = () => {
      transferDraft[key] = select.value;
    };
    wrapper.append(select);
    container.append(wrapper);
    controls[key] = select;
  }
  const folderActions = node("div", "action-row");
  for (const [label, operation] of [
    ["选择输出目录", "choose"],
    ["打开输出目录", "open"],
    ["恢复默认输出目录", "default"],
  ]) {
    const button = node("button", null, label);
    button.onclick = action(async () => {
      const directory = await command("transfer.directory", {
        action: operation,
        path: controls.transfer_dir.value,
      });
      if (typeof directory === "string")
        controls.transfer_dir.value = transferDraft.transfer_dir = directory;
    });
    folderActions.append(button);
  }
  container.append(
    folderActions,
    node(
      "p",
      "muted",
      "命名字段：{name} {category} {subcategory} {library} {index} {date} {region} {pitch} {rate} {gain} {direction} {variant} {variant_index}",
    ),
  );
  appendSettings(
    container,
    { ...settings, values: { ...settings.values, ...transferDraft } },
    "Transfer",
    (key, value) => {
      transferDraft[key] = value;
    },
  );
  const presets = node("div", "action-row");
  for (const [label, values] of transferPresets) {
    const button = node("button", null, label);
    button.onclick = action(async () => {
      Object.assign(transferDraft, {
        transfer_variants_enabled: true,
        ...values,
      });
      container.replaceChildren();
      await renderTransfer(container);
    });
    presets.append(button);
  }
  container.append(presets);
  const progress = node("p", "muted");
  progress.id = "transfer-progress";
  const summary = node("p", "muted");
  summary.id = "transfer-summary";
  const error = node("p", "error");
  error.id = "transfer-error";
  const submit = node("button", "primary", "导出所选声音");
  submit.id = "transfer-submit";
  const single = node("button", null, "导出当前素材");
  single.id = "transfer-current";
  const cancel = node("button", null, "当前文件后停止");
  cancel.id = "transfer-cancel";
  cancel.onclick = action(() => command("tasks.cancel", { task: "transfer" }));
  const exportAssets = async (target) => {
    for (const input of container.querySelectorAll("input"))
      if (!input.reportValidity()) return;
    if (!snapshot?.selectedCount) throw new Error("请先选择素材");
    submit.disabled = true;
    try {
      const values = Object.fromEntries(
        Object.entries(controls).map(([key, input]) => [key, input.value]),
      );
      const advanced = Object.fromEntries(
        Object.entries(transferDraft).filter(([key]) => !controls[key]),
      );
      await command("transfer.start", {
        ...values,
        values: advanced,
        target,
        path: target === "current" ? snapshot.selected.path : undefined,
      });
      transferDraft = { ...transferDraft, ...values };
    } catch (failure) {
      error.textContent = failure.message;
      throw failure;
    } finally {
      updateTransferStatus();
    }
  };
  submit.onclick = action(() => exportAssets("selected"));
  single.onclick = action(() => exportAssets("current"));
  const exports = node("div", "action-row");
  exports.append(single, submit, cancel);
  const output = node("p", "path-label");
  output.id = "transfer-last-output";
  const recent = node("button", null, "打开最近输出目录");
  recent.id = "transfer-recent";
  recent.onclick = action(() =>
    command("transfer.directory", { action: "recent" }),
  );
  const report = node("button", null, "打开任务报告目录");
  report.onclick = action(() =>
    command("transfer.directory", { action: "report" }),
  );
  const recentActions = node("div", "action-row");
  recentActions.append(recent, report);
  container.append(progress, summary, error, exports, output, recentActions);
  updateTransferStatus();
}
function updateTransferStatus() {
  if (!$("transfer-progress")) return;
  $("transfer-progress").textContent = snapshot?.transferProgress
    ? `${snapshot.transferProgress.completed} / ${snapshot.transferProgress.total}`
    : "";
  $("transfer-summary").textContent = snapshot?.transferSummary || "";
  $("transfer-error").textContent = snapshot?.transferError || "";
  $("transfer-submit").disabled =
    !snapshot?.selectedCount ||
    Boolean(snapshot?.tasks?.transfer) ||
    snapshot?.readOnly;
  $("transfer-current").disabled = $("transfer-submit").disabled;
  $("transfer-cancel").hidden = !snapshot?.tasks?.transfer;
  $("transfer-last-output").textContent =
    snapshot?.transferOutput || "尚未执行 Transfer";
  $("transfer-recent").disabled = !snapshot?.transferOutput;
}

let popoverAnchor;
function positionPopover() {
  const pop = $("popover");
  if (!popoverAnchor || !pop.matches(":popover-open")) return;
  const rect = popoverAnchor.getBoundingClientRect();
  const size = pop.getBoundingClientRect();
  pop.style.left = `${Math.max(8, Math.min(rect.left, innerWidth - size.width - 8))}px`;
  pop.style.top = `${Math.max(8, Math.min(rect.bottom + 5, innerHeight - size.height - 8))}px`;
}
new ResizeObserver(positionPopover).observe($("popover"));
function popover(anchor, content, actionMenu = false) {
  const pop = $("popover");
  popoverAnchor = anchor;
  pop.classList.toggle("action-menu", actionMenu);
  pop.replaceChildren(...content);
  pop.scrollTop = 0;
  if (!pop.matches(":popover-open")) pop.showPopover();
  positionPopover();
}

function toggle(label, checked, callback) {
  const wrapper = node("label");
  const checkbox = node("input");
  checkbox.type = "checkbox";
  checkbox.checked = checked;
  checkbox.onchange = () => callback(checkbox.checked);
  wrapper.append(checkbox, document.createTextNode(label));
  return wrapper;
}

function menu(anchor, entries, title, back) {
  const content = [];
  if (title) {
    const heading = node("h3", "menu-title", title);
    heading.dataset.literal = "true";
    heading.title = title;
    content.push(heading);
  }
  if (back) {
    const button = node("button", "menu-item menu-back", "‹ 返回");
    button.onclick = back;
    content.push(button, node("hr"));
  }
  for (const entry of entries) {
    if (!entry) {
      content.push(node("hr"));
      continue;
    }
    const [label, callback, shortcut, enabled = true] = entry;
    const item = node("button", "menu-item");
    item.type = "button";
    item.append(node("span", null, label));
    const submenu = Array.isArray(callback);
    if (submenu) {
      item.append(node("span", "submenu-arrow", "›"));
      item.setAttribute("aria-haspopup", "menu");
    } else if (shortcut) item.append(node("kbd", null, shortcut));
    item.disabled = !enabled;
    item.onclick = action(async () => {
      if (submenu) {
        menu(anchor, callback, undefined, () => {
          menu(anchor, entries, title, back);
          const items = [...$("popover").querySelectorAll(".menu-item")];
          items[
            entries.filter(Boolean).indexOf(entry) + (back ? 1 : 0)
          ]?.focus();
        });
        $("popover")
          .querySelector(".menu-item:not(.menu-back):not(:disabled)")
          ?.focus();
        return;
      }
      $("popover").hidePopover();
      await callback();
    });
    content.push(item);
  }
  popover(anchor, content, true);
}
function pointerAnchor(event) {
  return {
    getBoundingClientRect: () => ({
      left: event.clientX,
      bottom: event.clientY,
    }),
  };
}
function collectionCreateMenu(anchor) {
  menu(anchor, [
    ["新建播放列表", () => createCollection("playlist")],
    ["新建项目素材箱", () => createCollection("project")],
    [
      "绑定当前工程素材箱",
      () => command("records.action", { action: "currentProject" }),
    ],
  ]);
}
function managementMenu(event, kind, item) {
  const operations = {
    library: [
      ["添加来源", "add"],
      ["重命名", "rename"],
      ["扫描", "scan"],
      ["展开或折叠来源", "toggleSources"],
      ["移除音效库", "remove"],
    ],
    root: [
      ["打开来源文件夹", "open"],
      ["扫描来源", "scan"],
      ["重新链接", "relink"],
      ["指定封面", "artwork"],
      ["重新发现封面", "redetectArtwork"],
      ["清除封面", "clearArtwork"],
      ["移除来源", "remove"],
    ],
    collection: [
      ["加入所选素材", "addSelection"],
      ["移除所选素材", "removeSelection"],
      ...(item.kind === "project" ? [["绑定当前工程", "bind"]] : []),
      ...(item.kind === "project" ? [["查看当前工程已用素材", "used"]] : []),
      ["重命名", "rename"],
      ["删除集合", "remove"],
    ],
    search: [
      ["打开", "activate"],
      ["用当前条件覆盖", "overwrite"],
      ["重命名", "rename"],
      ["删除搜索", "remove"],
    ],
  };
  menu(
    pointerAnchor(event),
    operations[kind].map(([title, operation]) => [
      title,
      () => manageItem(kind, item, operation),
    ]),
  );
}
let filterSignature;
function renderFilterBar() {
  const signature = JSON.stringify([
    snapshot.search,
    snapshot.root,
    snapshot.libraryId,
    snapshot.collectionId,
    snapshot.statusFilter,
    snapshot.category,
    snapshot.catid,
    snapshot.view,
    snapshot.readOnly,
  ]);
  if (signature === filterSignature) return;
  filterSignature = signature;
  const chips = [];
  const add = (label, params) => {
    const chip = node("button", "filter-chip", `${label} ×`);
    chip.title = label;
    chip.onclick = action(() => {
      pageSequence++;
      $("result-scroll").scrollTop = 0;
      return command("catalog.query", { keepScope: true, ...params });
    });
    chips.push(chip);
  };
  if (snapshot.search) add(snapshot.search, { search: "" });
  if (snapshot.root) add(snapshot.root, { root: "" });
  if (snapshot.libraryId)
    add(
      snapshot.libraries.find((item) => item.id === snapshot.libraryId)?.name ||
        "音效库",
      { libraryId: "", root: "" },
    );
  if (snapshot.collectionId)
    add(
      snapshot.collections.find((item) => item.id === snapshot.collectionId)
        ?.name || "集合",
      { collectionId: "" },
    );
  if (snapshot.catid || snapshot.category)
    add(snapshot.catid || snapshot.category, {
      category: "",
      subcategory: "",
      catid: "",
      view: "all",
    });
  if (snapshot.statusFilter)
    add(
      snapshot.workflowStatuses?.find(
        (item) => item.id === snapshot.statusFilter,
      )?.label || snapshot.statusFilter,
      { status: "" },
    );
  $("filter-bar").hidden = !chips.length;
  $("filter-bar").replaceChildren(...chips);
}
const taskLabels = {
  scan: "扫描",
  import: "导入",
  transfer: "交付",
  similar: "相似检索",
  ai: "AI 搜索",
  precache: "波形预生成",
  classify: "分类",
  relink: "重新链接",
  remove: "移除来源",
  verify: "缓存校验",
  missing: "缺失检查",
  duplicates: "重复检查",
  transients: "瞬态检测",
  loudness: "响度分析",
};
$("tasks-open").onclick = () => {
  const entries = Object.entries(snapshot?.tasks || {}).filter(
    ([, active]) => active,
  );
  menu(
    $("tasks-open"),
    entries.length
      ? entries.map(([task]) => [
          `停止 · ${taskLabels[task] || task}`,
          () => command("tasks.cancel", { task }),
        ])
      : [
          ["当前没有后台任务", () => {}, "", false],
          ["维护与恢复", () => settingsDialog("maintenance")],
        ],
  );
};
$("clear-query").onclick = action(() => {
  $("search").value = "";
  return query({ search: "" });
});
$("toast-close").onclick = () => {
  $("toast").hidden = true;
  clearTimeout(reportTimer);
};
for (const button of document.querySelectorAll("[data-rail]"))
  button.onclick = action(async () => {
    const target = button.dataset.rail;
    openNavigation(target);
    if (["all", "favorites", "previewed"].includes(target))
      await query({ view: target });
  });
for (const button of document.querySelectorAll("[data-menu]"))
  button.onclick = () => {
    const selected = Boolean(snapshot?.selected);
    const operate = (actionName) =>
      command("asset.action", { action: actionName });
    const menus = {
      file: [
        ["添加音效库", () => command("library.add")],
        ["保存当前搜索", saveSearch],
        null,
        [
          "打开数据目录",
          () => command("records.action", { action: "dataFolder" }),
        ],
        ["设置与维护", () => settingsDialog()],
      ],
      library: [
        ["音效库与来源", () => settingsDialog("libraries")],
        [
          "扫描来源",
          () => command("maintenance", { action: "scan" }),
          "Ctrl+R",
        ],
        ["新建播放列表", () => createCollection("playlist")],
        ["新建项目素材箱", () => createCollection("project")],
        null,
        ["UCS 分类预览", () => settingsDialog("maintenance")],
        ["维护与恢复", () => settingsDialog("maintenance")],
      ],
      edit: [
        [
          "全选",
          () => command("selection.all").then(() => requestPage()),
          "Ctrl+A",
        ],
        ["收藏 / 取消收藏", () => operate("favorite"), "F", selected],
        ["标记 / 取消标记", () => operate("mark"), "M", selected],
        [
          "复制完整路径",
          () => navigator.clipboard.writeText(snapshot.selected.path),
          "",
          selected,
        ],
        null,
        [
          "批量元数据",
          () => {
            prefs.right = true;
            applyPreferences();
            document.querySelector('[data-inspector="metadata"]').click();
          },
          "",
          selected,
        ],
      ],
      view: [
        [
          "新建标签页",
          () => command("tab.action", { action: "new" }),
          "Ctrl+N",
        ],
        [
          "复制标签页",
          () =>
            command("tab.action", {
              action: "new",
              duplicateId: snapshot.activeTab,
            }),
          "Ctrl+Shift+N",
        ],
        null,
        ["来源侧栏", () => $("left-toggle").click(), "F9"],
        ["检查器", () => $("right-toggle").click(), "F10"],
        ["显示列", () => columnsMenu(button)],
        ["外观与布局", () => settingsDialog("appearance")],
      ],
      transfer: [
        ["Transfer 交付", () => $("transfer-open").click(), "Ctrl+T"],
        ["交付默认设置", () => settingsDialog("transfer")],
        null,
        ["插入当前轨道", () => command("insert"), "", selected],
        [
          "插入新轨道",
          () => command("insert", { newTrack: true }),
          "",
          selected,
        ],
        ["堆叠插入到新轨道", () => operate("stack"), "", selected],
        [
          "按 BWF 时间戳插入",
          () => command("insert", { bwf: true }),
          "",
          selected,
        ],
      ],
      help: [
        ["快捷键与使用说明", () => settingsDialog("about")],
        [
          "打开文档目录",
          () => command("records.action", { action: "docsFolder" }),
        ],
        ["AI 语义搜索", () => settingsDialog("ai")],
        [
          "复制诊断信息",
          async () =>
            navigator.clipboard.writeText(await command("diagnostics.get")),
        ],
      ],
    };
    menu(button, menus[button.dataset.menu]);
  };
$("popover").addEventListener("keydown", (event) => {
  if (event.key === "ArrowLeft" && $("popover").querySelector(".menu-back")) {
    event.preventDefault();
    $("popover").querySelector(".menu-back").click();
    return;
  }
  if (
    event.key === "ArrowRight" &&
    event.target.matches('[aria-haspopup="menu"]')
  ) {
    event.preventDefault();
    event.target.click();
    return;
  }
  if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return;
  const items = [
    ...$("popover").querySelectorAll("button:not(:disabled),input"),
  ];
  if (!items.length) return;
  event.preventDefault();
  event.stopPropagation();
  const index = items.indexOf(document.activeElement);
  const next =
    event.key === "Home"
      ? 0
      : event.key === "End"
        ? items.length - 1
        : (index + (event.key === "ArrowDown" ? 1 : -1) + items.length) %
          items.length;
  items[next].focus();
});

function columnsMenu(anchor, layout = false) {
  const content = [node("h3", null, layout ? "布局与显示" : "显示列")];
  if (layout) {
    content.push(
      toggle("来源侧栏", prefs.left, (value) => {
        prefs.left = value;
        applyPreferences();
        persist();
      }),
    );
    content.push(
      toggle("检查器", prefs.right, (value) => {
        prefs.right = value;
        applyPreferences();
        persist();
      }),
    );
    content.push(
      toggle("FX 面板", prefs.fx, (value) => {
        prefs.fx = value;
        applyPreferences();
        persist();
      }),
    );
    content.push(
      toggle("纸白墨绿主题", prefs.theme === "paper", (value) => {
        prefs.theme = value ? "paper" : "dark";
        applyPreferences();
        persist();
      }),
    );
    content.push(node("hr"));
  }
  for (const [key, label] of orderedColumns()) {
    content.push(
      toggle(label, Boolean(prefs.columns[key]), (value) => {
        prefs.columns[key] = value;
        if (!visibleColumns().length) prefs.columns.name = true;
        applyPreferences();
        persist();
        requestPage();
      }),
    );
  }
  const order = node("details", "settings-section");
  order.append(node("summary", null, "调整列顺序"));
  for (const [key, label] of orderedColumns()) {
    const button = node("button", "menu-item", `↑ ${label}`);
    button.onclick = () => {
      const keys = orderedColumns().map(([name]) => name);
      const index = keys.indexOf(key);
      if (index > 0)
        [keys[index - 1], keys[index]] = [keys[index], keys[index - 1]];
      prefs.columnOrder = keys;
      persist();
      applyPreferences();
      columnsMenu(anchor, layout);
    };
    order.append(button);
  }
  content.push(order);
  for (const [title, reset] of [
    [
      "重置默认字段",
      () => {
        prefs.columns = structuredClone(defaults.columns);
        prefs.columnOrder = [];
      },
    ],
    [
      "重置列宽",
      () => {
        prefs.widths = structuredClone(defaults.widths);
      },
    ],
  ]) {
    const button = node("button", "menu-item", title);
    button.onclick = () => {
      reset();
      applyPreferences();
      persist();
      requestPage();
      columnsMenu(anchor, layout);
    };
    content.push(button);
  }
  popover(anchor, content);
}

function rowMenu(event, asset) {
  const operate = async (operation, extra = {}) => {
    const result = await command("asset.action", {
      path: asset.path,
      action: operation,
      ...extra,
    });
    requestPage();
    return result;
  };
  const select = async () => {
    if (!asset.selected) await selectAsset(asset, {}, false);
  };
  menu(
    pointerAnchor(event),
    [
      ["试听", () => operate("play"), "Space"],
      [asset.favorite ? "取消收藏" : "收藏", () => operate("favorite"), "F"],
      [asset.marked ? "取消标记" : "标记", () => operate("mark"), "M"],
      null,
      [
        "插入 REAPER",
        [
          ["插入当前轨道", () => operate("insert")],
          ["插入新轨道", () => operate("insert", { newTrack: true })],
          [
            "堆叠插入到新轨道",
            async () => {
              await select();
              await operate("stack");
            },
          ],
          ["按 BWF 时间戳插入", () => operate("insert", { bwf: true })],
        ],
      ],
      [
        "集合",
        [
          ...(snapshot?.collections || []).map((collection) => [
            collection.name,
            async () => {
              await select();
              await command("collection.add", { id: collection.id });
            },
          ]),
          null,
          [
            "新建播放列表",
            async () => {
              await select();
              await createCollection("playlist");
            },
          ],
          [
            "新建项目素材箱",
            async () => {
              await select();
              await createCollection("project");
            },
          ],
          [
            "从当前集合移除",
            () => operate("removeCollection"),
            "",
            Boolean(snapshot?.collectionId),
          ],
        ],
      ],
      [
        "查找相似声音",
        [
          [
            "在当前结果中查找相似声音",
            () => operate("similar", { scope: "current" }),
          ],
          [
            "在全部音效库中查找相似声音",
            () => operate("similar", { scope: "all" }),
          ],
          ["定位所属产品音效库", () => operate("browseProduct")],
        ],
      ],
      [
        "分析与元数据",
        [
          ["重新读取元数据", () => operate("metadata")],
          ["重新分析响度", () => operate("loudness")],
          ["检测瞬态", () => operate("transients")],
          ["撤销瞬态检测", () => operate("undoTransients")],
          ["清除瞬态建议", () => operate("clearTransients")],
          ["撤销 UCS 确认", () => operate("undoUcs")],
        ],
      ],
      [
        "封面",
        [
          ["选择封面", () => operate("artwork")],
          ["自动查找封面", () => operate("redetectArtwork")],
          ["清除封面", () => operate("clearArtwork")],
        ],
      ],
      [
        "工作流状态",
        (snapshot?.workflowStatuses || []).map((status) => [
          status.label,
          () => operate("workflow", { status: status.id }),
        ]),
      ],
      null,
      ["复制完整路径", () => navigator.clipboard.writeText(asset.path)],
      ["显示文件", () => host.reveal(asset.path)],
    ],
    asset.name,
  );
}

function appendSettings(container, settings, groupFilter, onChange) {
  const groups = new Map();
  for (const definition of settings.schema || []) {
    if (groupFilter && definition.group !== groupFilter) continue;
    if (
      groupFilter === "Transfer" &&
      [
        "transfer_dir",
        "transfer_template",
        "transfer_format",
        "transfer_sample_rate",
        "transfer_channels",
        "transfer_scope",
      ].includes(definition.key)
    )
      continue;
    let group = groups.get(definition.group);
    if (!group) {
      group = node("details", "settings-section");
      group.append(node("summary", null, definition.group));
      groups.set(definition.group, group);
      container.append(group);
    }
    const wrapper = node("label", "field");
    wrapper.append(node("span", null, definition.label));
    const input = node(definition.kind === "choice" ? "select" : "input");
    input.dataset.setting = definition.key;
    if (definition.kind === "choice") {
      for (const option of definition.options)
        input.add(
          new Option(
            definition.key === "language"
              ? { zh: "简体中文", en: "English" }[option]
              : option,
            option,
          ),
        );
    } else {
      input.type =
        { boolean: "checkbox", number: "number", color: "color" }[
          definition.kind
        ] || "text";
    }
    if (definition.kind === "boolean")
      input.checked = settings.values[definition.key];
    else input.value = settings.values[definition.key] ?? "";
    if (definition.kind === "number") {
      input.min = definition.minimum;
      input.max = definition.maximum;
      input.step = definition.integer ? "1" : "any";
    }
    input.onchange = action(async () => {
      if (!input.reportValidity()) return;
      const value =
        definition.kind === "boolean"
          ? input.checked
          : definition.kind === "number"
            ? Number(input.value)
            : input.value;
      if (onChange) onChange(definition.key, value);
      else {
        await command("settings.update", {
          values: { [definition.key]: value },
        });
        requestPage();
      }
    });
    wrapper.append(input);
    group.append(wrapper);
  }
}

function renderClassificationReview() {
  const container = $("classification-review");
  if (!container) return;
  const review = snapshot?.classificationReview;
  const signature = JSON.stringify(review);
  if (container.dataset.signature === signature) return;
  container.dataset.signature = signature;
  container.replaceChildren();
  if (!review) return;
  container.append(node("h3", null, "UCS 分类预览"));
  const counts = review.counts;
  container.append(
    node(
      "p",
      null,
      `检查 ${review.total} · 可更新 ${counts.changed} · 自动 ${counts.auto} · 待确认 ${counts.pending} · 人工保护 ${counts.manual}`,
    ),
  );
  for (const sample of review.samples || [])
    container.append(
      node(
        "p",
        "muted",
        `${sample.name}：${sample.before || "未分类"} → ${sample.after || sample.candidates || "未分类"}`,
      ),
    );
  const discard = node("button", null, "丢弃分类预览");
  discard.type = "button";
  discard.onclick = action(() =>
    command("maintenance", { action: "classifyDiscard" }),
  );
  container.append(discard);
}

const settings = createSettings({
  dialog: $("settings-dialog"),
  command,
  getPreferences: () => structuredClone(prefs),
  setPreferences: (value) => {
    prefs = { ...value, language: snapshot?.language || prefs.language };
    applyPreferences();
    persist();
    sidebarSignature = null;
    if (snapshot) renderSidebar();
  },
  defaults,
  getHost: () => host,
  getSnapshot: () => snapshot,
  afterChange: () => requestPage(),
  renderReview: renderClassificationReview,
  manage: manageItem,
  createCollection,
});
function settingsDialog(section) {
  return settings.open(section);
}

function promptName(title, value = "", description = "") {
  return new Promise((resolve) => {
    const dialog = $("input-dialog");
    if (dialog.open) {
      resolve(null);
      return;
    }
    $("input-title").textContent = title;
    $("input-description").textContent = description;
    $("input-value").value = value;
    let result = null;
    $("input-form").onsubmit = (event) => {
      event.preventDefault();
      if (!$("input-value").reportValidity() || !$("input-value").value.trim())
        return;
      result = $("input-value").value.trim();
      dialog.close();
    };
    $("input-cancel").onclick = () => dialog.close();
    dialog.addEventListener("close", () => resolve(result), { once: true });
    dialog.showModal();
    $("input-value").focus();
    $("input-value").select();
  });
}
async function createCollection(kind) {
  const name = await promptName(
    kind === "project" ? "新建项目素材箱" : "新建播放列表",
  );
  if (name === null) return false;
  return command("collection.create", { kind, name });
}
async function manageItem(kind, item, operation) {
  if (operation === "toggleSources" && kind === "library") {
    const collapsed = new Set(prefs.collapsedLibraries || []);
    if (collapsed.has(item.id)) collapsed.delete(item.id);
    else collapsed.add(item.id);
    prefs.collapsedLibraries = [...collapsed];
    renderSidebar();
    persist();
    return true;
  }
  if (operation === "used" && kind === "collection") {
    openNavigation("all");
    return query({ view: "project_used" });
  }
  const params = { kind, id: item.id, action: operation };
  if (operation === "rename") {
    params.name = await promptName("重命名", item.name);
    if (params.name === null) return false;
  }
  return command("management.action", params);
}
async function saveSearch() {
  const name = await promptName("保存当前搜索", $("search").value);
  if (name !== null)
    return command("records.action", { action: "saveSearch", name });
}
async function saveRegion() {
  if (
    !snapshot?.selected ||
    snapshot.regionEnd - snapshot.regionStart < 0.002 ||
    snapshot.regionEnd - snapshot.regionStart >= 0.998
  )
    throw new Error("请先在大波形中建立有效选区");
  const name = await promptName(
    "保存当前选区为 Region",
    `Region ${(snapshot.selected.regions?.length || 0) + 1}`,
  );
  if (name !== null)
    return command("region.action", {
      action: "save",
      name,
      path: snapshot.selected.path,
    });
}

let suggestionTimer;
let suggestionSequence = 0;
let suggestions = [];
let activeSuggestion = -1;
const suggestionBox = $("search-suggestions");
function hideSearchSuggestions() {
  ++suggestionSequence;
  clearTimeout(suggestionTimer);
  if (suggestionBox.matches(":popover-open")) suggestionBox.hidePopover();
  $("search").setAttribute("aria-expanded", "false");
  $("search").removeAttribute("aria-activedescendant");
  activeSuggestion = -1;
}
async function chooseSuggestion(index) {
  const suggestion = suggestions[index];
  if (!suggestion) return;
  hideSearchSuggestions();
  $("search").value = suggestion.query;
  $("result-scroll").scrollTop = 0;
  await command("catalog.query", { search: suggestion.query, keepScope: true });
  $("search").focus();
}
$("search").addEventListener("input", () => {
  hideSearchSuggestions();
  const sequence = suggestionSequence;
  const query = $("search").value;
  if (query.trim().length < 2) return;
  suggestionTimer = setTimeout(
    action(async () => {
      const result = await command("catalog.suggestions", { query });
      if (
        sequence !== suggestionSequence ||
        document.activeElement !== $("search")
      )
        return;
      suggestions = result;
      if (!suggestions.length) return;
      suggestionBox.replaceChildren(
        ...suggestions.map((suggestion, index) => {
          const button = node("button", "menu-item", suggestion.label);
          button.type = "button";
          button.id = `ucs-suggestion-${index}`;
          button.setAttribute("role", "option");
          button.setAttribute("aria-selected", "false");
          button.tabIndex = -1;
          button.title = suggestion.detail;
          button.onpointerdown = (event) => event.preventDefault();
          button.onclick = action(() => chooseSuggestion(index));
          return button;
        }),
      );
      const rect = $("search-form").getBoundingClientRect();
      suggestionBox.style.left = `${rect.left}px`;
      suggestionBox.style.top = `${rect.bottom + 4}px`;
      suggestionBox.style.width = `${Math.min(rect.width, innerWidth - rect.left - 8)}px`;
      suggestionBox.showPopover();
      $("search").setAttribute("aria-expanded", "true");
    }),
    150,
  );
});
$("search").addEventListener(
  "keydown",
  action(async (event) => {
    if (!suggestionBox.matches(":popover-open")) return;
    if (event.key === "Escape") {
      event.preventDefault();
      hideSearchSuggestions();
      return;
    }
    if (event.key === "Enter" && activeSuggestion >= 0) {
      event.preventDefault();
      await chooseSuggestion(activeSuggestion);
    } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      activeSuggestion =
        (activeSuggestion +
          (event.key === "ArrowDown" ? 1 : -1) +
          suggestions.length) %
        suggestions.length;
      for (const [index, option] of [...suggestionBox.children].entries())
        option.setAttribute(
          "aria-selected",
          String(index === activeSuggestion),
        );
      $("search").setAttribute(
        "aria-activedescendant",
        `ucs-suggestion-${activeSuggestion}`,
      );
      suggestionBox.children[activeSuggestion].scrollIntoView({
        block: "nearest",
      });
    }
  }),
);
suggestionBox.addEventListener("toggle", (event) => {
  if (event.newState === "closed")
    $("search").setAttribute("aria-expanded", "false");
});
$("search").addEventListener("blur", () =>
  setTimeout(() => {
    if (
      document.activeElement !== $("search") &&
      !suggestionBox.contains(document.activeElement)
    )
      hideSearchSuggestions();
  }, 0),
);

$("search-form").onsubmit = action((event) => {
  event.preventDefault();
  hideSearchSuggestions();
  $("result-scroll").scrollTop = 0;
  return command("catalog.query", {
    search: $("search").value,
    keepScope: true,
  });
});
$("scope").onchange = action(() => query({ libraryId: $("scope").value }));
$("ai-search").onclick = action(() =>
  command("search.ai", { query: $("search").value }),
);
$("ai-more").onclick = action(() => command("search.more"));
$("result-scroll").onscroll = () => {
  $("column-head").scrollLeft = $("result-scroll").scrollLeft;
  requestPage(false);
};
$("sort").onchange = action(() =>
  command("catalog.sort", {
    field: $("sort").value,
    descending: sortDescending,
  }),
);
$("sort-direction").onclick = action(() => {
  sortDescending = !sortDescending;
  $("sort-direction").textContent = sortDescending ? "↓" : "↑";
  return command("catalog.sort", {
    field: $("sort").value,
    descending: sortDescending,
  });
});
$("columns-open").onclick = () => columnsMenu($("columns-open"));
$("layout-menu").onclick = () => columnsMenu($("layout-menu"), true);
$("left-toggle").onclick = () => {
  prefs.left = !prefs.left;
  applyPreferences();
  persist();
};
$("right-toggle").onclick = () => {
  prefs.right = !prefs.right;
  applyPreferences();
  persist();
};
$("fx-toggle").onclick = () => {
  prefs.fx = !prefs.fx;
  applyPreferences();
  persist();
};
$("fx-panel").ontoggle = () => {
  if (prefs.fx === $("fx-panel").open) return;
  prefs.fx = $("fx-panel").open;
  applyPreferences();
  persist();
  drawDetail();
};
$("new-tab").onclick = action(() => command("tab.action", { action: "new" }));
$("play").onclick = action(() => command("preview.toggle"));
$("stop").onclick = action(() => command("preview.stop"));
$("loop").onclick = action(() =>
  command("preview.parameters", { loop: !snapshot?.fx.loop }),
);
$("auto-preview").onchange = action(() =>
  command("preview.parameters", { auto_preview: $("auto-preview").checked }),
);
$("insert").onclick = action(() => command("insert"));
$("similar-search").onclick = () =>
  menu($("similar-search"), [
    [
      "在当前结果内查找相似声音",
      () => command("search.similar", { scope: "current" }),
    ],
    [
      "在全部音效库中查找相似声音",
      () => command("search.similar", { scope: "all" }),
    ],
    ["首次分析会建立缓存，可在后台运行", () => {}, "", false],
  ]);
$("audition-more").onclick = action(async () => {
  const { values } = await command("settings.get");
  const checked = (key, label) => [
    `${values[key] ? "✓ " : ""}${label}`,
    () => command("settings.update", { values: { [key]: !values[key] } }),
  ];
  menu($("audition-more"), [
    ["适应完整波形", () => $("zoom-reset").click()],
    ["FX 面板", () => $("fx-toggle").click()],
    [
      "试听选项",
      [
        checked("loop_selection", "循环波形选区"),
        checked("spectral_peaks_enabled", "频谱波形"),
        checked("loudness_match", "响度匹配"),
        checked("show_loudness_metrics", "显示响度读数"),
        [
          "保持音高",
          () =>
            command("preview.parameters", {
              preserve_pitch: !snapshot?.fx.preserve_pitch,
            }),
        ],
        [
          "反向",
          () =>
            command("preview.parameters", { reverse: !snapshot?.fx.reverse }),
        ],
        ["循环", () => $("loop").click()],
      ],
    ],
    ["保存当前选区为 Region", saveRegion, "", Boolean(snapshot?.selected)],
    [
      "清除波形选区",
      () => command("preview.clearRegion"),
      "",
      Boolean(snapshot?.selected),
    ],
    [
      "Region 列表",
      () => {
        prefs.right = true;
        applyPreferences();
        persist();
        document.querySelector('[data-inspector="regions"]').click();
      },
    ],
    [
      "分析",
      [
        ...[
          ["重新分析响度", "loudness"],
          ["检测瞬态", "transients"],
          ["撤销瞬态检测", "undoTransients"],
          ["清除瞬态建议", "clearTransients"],
        ].map(([label, operation]) => [
          label,
          () =>
            command("asset.action", {
              action: operation,
              path: snapshot.selected.path,
            }),
          "",
          Boolean(snapshot?.selected),
        ]),
        ["波形与分析设置", () => settingsDialog("waveform")],
      ],
    ],
    [
      "按 BWF 时间戳插入",
      () => command("insert", { bwf: true }),
      "",
      Boolean(snapshot?.selected),
    ],
  ]);
});
$("analysis-cancel").onclick = action(() =>
  command("tasks.cancel", { task: "similar" }),
);
$("wave-retry").onclick = action(() => requestDetailWave(true));
$("save-region").onclick = action(saveRegion);
$("cancel-tasks").onclick = action(() => command("tasks.cancel"));
$("settings-open").onclick = action(settingsDialog);
for (const button of document.querySelectorAll("[data-inspector]")) {
  button.onclick = () => {
    inspectorTab = button.dataset.inspector;
    for (const item of document.querySelectorAll("[data-inspector]"))
      item.classList.toggle("active", item === button);
    renderInspector();
  };
}
$("transfer-open").onclick = () => {
  prefs.right = true;
  applyPreferences();
  persist();
  document.querySelector('[data-inspector="transfer"]').click();
};
for (const id of ["add-library", "empty-add"])
  $(id).onclick = action(async () => {
    await command("library.add");
    prefs.left = true;
    applyPreferences();
    persist();
  });
$("new-collection").onclick = () => collectionCreateMenu($("new-collection"));
function renderUcs() {
  if (!ucsCatalog) return;
  const search = $("ucs-search").value.trim().toLocaleLowerCase();
  const words = search.split(/\s+/).filter(Boolean);
  const fragment = document.createDocumentFragment();
  let count = 0;
  for (const category of ucsCatalog) {
    const entries = category.entries.filter((entry) => {
      const text = [
        category.name,
        category.label,
        entry.catid,
        entry.name,
        entry.label,
        entry.synonyms,
      ]
        .join(" ")
        .toLocaleLowerCase();
      return words.every((word) => text.includes(word));
    });
    if (!entries.length) continue;
    count += entries.length;
    const details = node("details");
    details.open = Boolean(search) || ucsOpen.has(category.name);
    details.append(
      node(
        "summary",
        "section-label",
        prefs.language === "en"
          ? category.name
          : category.label || category.name,
      ),
    );
    details.ontoggle = () => {
      if (search) return;
      if (details.open) ucsOpen.add(category.name);
      else ucsOpen.delete(category.name);
    };
    details.append(
      navItem(
        `${prefs.language === "en" ? "All" : "全部"} ${category.name}`,
        () => query({ category: category.name }),
        snapshot?.category === category.name,
      ),
    );
    for (const entry of entries)
      details.append(
        navItem(
          `${entry.catid} · ${prefs.language === "en" ? entry.name : entry.label || entry.name}`,
          () => query({ catid: entry.catid }),
          snapshot?.catid === entry.catid,
          "root",
        ),
      );
    fragment.append(details);
  }
  $("ucs-categories").replaceChildren(fragment);
  $("ucs-search-clear").hidden = !search;
  $("ucs-search-status").hidden = !search;
  $("ucs-search-status").textContent = count
    ? `${count} 个分类`
    : "没有匹配的 UCS 分类";
}
async function loadUcs() {
  if (!ucsCatalog) {
    ucsLoading ||= command("catalog.ucs").finally(() => {
      ucsLoading = null;
    });
    ucsCatalog = await ucsLoading;
  }
  renderUcs();
}
$("ucs-directory").ontoggle = action(async () => {
  if ($("ucs-directory").open) await loadUcs();
});
$("ucs-search").oninput = action(loadUcs);
$("ucs-search-clear").onclick = () => {
  $("ucs-search").value = "";
  renderUcs();
  $("ucs-search").focus();
};
$("collection-menu").onclick = () => {
  const content = [node("h3", null, "将所选声音加入集合")];
  for (const collection of snapshot?.collections || []) {
    const button = node(
      "button",
      "menu-item",
      `${collection.name} · ${collection.count}`,
    );
    button.onclick = action(async () => {
      await command("collection.add", { id: collection.id });
      $("popover").hidePopover();
    });
    content.push(button);
  }
  for (const [label, kind] of [
    ["＋ 新建项目素材箱", "project"],
    ["＋ 新建播放列表", "playlist"],
  ]) {
    const create = node("button", "menu-item", label);
    create.onclick = action(async () => {
      $("popover").hidePopover();
      await createCollection(kind);
    });
    content.push(create);
  }
  popover($("collection-menu"), content);
};
$("fx-presets").onclick = () =>
  menu($("fx-presets"), [
    [
      "音高预设",
      [-12, -6, -3, 0, 3, 6, 12].map((pitch) => [
        `${pitch > 0 ? "+" : ""}${pitch} st`,
        () => command("preview.parameters", { pitch }),
      ]),
    ],
    [
      "速度预设",
      [0.5, 0.75, 1, 1.25, 1.5, 2].map((rate) => [
        `${rate}×`,
        () => command("preview.parameters", { rate }),
      ]),
    ],
  ]);
let fxTimer;
let pendingFx = {};
for (const [label, key] of [
  ["pitch", "pitch"],
  ["rate", "rate"],
  ["gain", "gain_db"],
]) {
  for (const id of [`fx-${label}`, `fx-${label}-value`]) {
    $(id).oninput = () => {
      const value = clamp($(id).value, Number($(id).min), Number($(id).max));
      $(`fx-${label}`).value = value;
      $(`fx-${label}-value`).value = value;
      pendingFx[key] = value;
      clearTimeout(fxTimer);
      fxTimer = setTimeout(() => {
        const values = pendingFx;
        pendingFx = {};
        command("preview.parameters", values).catch(report);
      }, 60);
    };
  }
}
$("preserve-pitch").onchange = action(() =>
  command("preview.parameters", {
    preserve_pitch: $("preserve-pitch").checked,
  }),
);
$("reverse").onchange = action(() =>
  command("preview.parameters", { reverse: $("reverse").checked }),
);
$("fx-reset").onclick = action(() =>
  command("preview.parameters", {
    pitch: 0,
    rate: 1,
    gain_db: 0,
    preserve_pitch: true,
    reverse: false,
  }),
);
$("zoom-reset").onclick = () => {
  zoomStart = 0;
  zoomEnd = 1;
  drawDetail();
};

const detailCanvas = $("detail-wave");
attachArrangeDrag($("drag-selection"), () => snapshot?.selected?.path, true);
function wavePercent(event) {
  const rect = detailCanvas.getBoundingClientRect();
  return clamp(
    zoomStart +
      ((event.clientX - rect.left) / rect.width) * (zoomEnd - zoomStart),
    0,
    1,
  );
}
let wavePanX = null;
let lastScrub = 0;
detailCanvas.oncontextmenu = (event) => event.preventDefault();
detailCanvas.onpointerdown = (event) => {
  if (event.button === 1) {
    event.preventDefault();
    wavePanX = event.clientX;
    detailCanvas.setPointerCapture(event.pointerId);
    return;
  }
  if (event.button !== 0 || !snapshot?.selected) return;
  regionDrag = { start: wavePercent(event), current: wavePercent(event) };
  detailCanvas.setPointerCapture(event.pointerId);
};
detailCanvas.onpointermove = (event) => {
  if (wavePanX !== null) {
    const span = zoomEnd - zoomStart;
    const delta =
      ((wavePanX - event.clientX) /
        detailCanvas.getBoundingClientRect().width) *
      span;
    zoomStart = clamp(zoomStart + delta, 0, 1 - span);
    zoomEnd = zoomStart + span;
    wavePanX = event.clientX;
    drawDetail();
    return;
  }
  if (
    event.buttons & 2 &&
    snapshot?.waveScrub &&
    performance.now() - lastScrub >= 90
  ) {
    lastScrub = performance.now();
    command("preview.play", {
      position: wavePercent(event),
      selection: false,
    }).catch(report);
  }
  if (!regionDrag) return;
  regionDrag.current = wavePercent(event);
  drawDetail();
  updateReadouts();
};
detailCanvas.onpointerup = action(async (event) => {
  wavePanX = null;
  if (!regionDrag) return;
  const start = Math.min(regionDrag.start, regionDrag.current);
  const finish = Math.max(regionDrag.start, regionDrag.current);
  regionDrag = null;
  if (Math.abs(finish - start) < 0.001) {
    await command("preview.play", { position: start, selection: false });
  } else {
    await command("preview.region", { start, finish });
    await command("preview.play", { position: start, selection: true });
  }
});
detailCanvas.onpointercancel = () => {
  wavePanX = null;
  regionDrag = null;
  drawDetail();
};
detailCanvas.ondblclick = () => $("zoom-reset").click();
detailCanvas.onwheel = (event) => {
  event.preventDefault();
  if (event.shiftKey) {
    const span = zoomEnd - zoomStart;
    zoomStart = clamp(
      zoomStart + Math.sign(event.deltaY) * span * 0.1,
      0,
      1 - span,
    );
    zoomEnd = zoomStart + span;
    drawDetail();
    return;
  }
  const anchor = wavePercent(event);
  const oldSpan = zoomEnd - zoomStart;
  const span = clamp(oldSpan * (event.deltaY > 0 ? 1.25 : 0.8), 0.005, 1);
  const fraction = (anchor - zoomStart) / oldSpan;
  zoomStart = clamp(anchor - span * fraction, 0, 1 - span);
  zoomEnd = zoomStart + span;
  drawDetail();
};

function attachSplitter(element, key, dimension, multiplier) {
  element.onpointerdown = (event) => {
    event.preventDefault();
    element.setPointerCapture(event.pointerId);
    const origin = event[dimension];
    const original = prefs[key];
    const move = (moved) => {
      prefs[key] = original + (moved[dimension] - origin) * multiplier;
      applyPreferences();
    };
    const finish = () => {
      element.removeEventListener("pointermove", move);
      persist();
      requestPage();
    };
    element.addEventListener("pointermove", move);
    element.addEventListener("pointerup", finish, { once: true });
    element.addEventListener("pointercancel", finish, { once: true });
  };
  element.onkeydown = (event) => {
    const sign = ["ArrowLeft", "ArrowUp"].includes(event.key)
      ? -1
      : ["ArrowRight", "ArrowDown"].includes(event.key)
        ? 1
        : 0;
    if (!sign) return;
    event.preventDefault();
    prefs[key] += sign * 12 * multiplier;
    applyPreferences();
    persist();
    requestPage();
  };
}
attachSplitter(
  document.querySelector('[data-resize="left"]'),
  "leftWidth",
  "clientX",
  1,
);
attachSplitter(
  document.querySelector('[data-resize="right"]'),
  "rightWidth",
  "clientX",
  -1,
);
attachSplitter($("audition-splitter"), "auditionHeight", "clientY", -1);
// Capture Space before focused buttons perform their default click. One press
// means one backend toggle, even while a previous state snapshot is in flight.
let auditionSpaceDown = false;
window.addEventListener(
  "keydown",
  (event) => {
    if (
      !host ||
      event.code !== "Space" ||
      event.ctrlKey ||
      event.metaKey ||
      event.altKey ||
      event.shiftKey ||
      event.isComposing ||
      event.keyCode === 229 ||
      event.defaultPrevented ||
      event.target.closest(
        'input,textarea,select,[contenteditable]:not([contenteditable="false"]),dialog,#popover',
      )
    )
      return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (auditionSpaceDown || event.repeat) return;
    auditionSpaceDown = true;
    command("preview.toggle").catch(report);
  },
  true,
);
window.addEventListener(
  "keyup",
  (event) => {
    if (event.code !== "Space" || !auditionSpaceDown) return;
    auditionSpaceDown = false;
    event.preventDefault();
    event.stopImmediatePropagation();
  },
  true,
);
window.addEventListener("blur", () => {
  auditionSpaceDown = false;
});
document.addEventListener(
  "keydown",
  action(async (event) => {
    if (
      !host ||
      event.defaultPrevented ||
      event.repeat ||
      event.isComposing ||
      event.target.closest("dialog,#popover")
    )
      return;
    if (
      (event.ctrlKey || event.metaKey) &&
      event.shiftKey &&
      event.key.toLowerCase() === "f"
    ) {
      event.preventDefault();
      await command("search.ai", { query: $("search").value });
      return;
    }
    if (
      event.target.closest(
        'input,textarea,select,dialog,[contenteditable]:not([contenteditable="false"])',
      )
    )
      return;
    const ctrl = event.ctrlKey || event.metaKey;
    if (ctrl && event.key.toLowerCase() === "f") {
      event.preventDefault();
      if (event.shiftKey)
        await command("search.ai", { query: $("search").value });
      else $("search").focus();
      return;
    }
    if (ctrl && event.key.toLowerCase() === "r") {
      event.preventDefault();
      await command("maintenance", { action: "scan" });
      return;
    }
    if (ctrl && event.key.toLowerCase() === "t") {
      event.preventDefault();
      $("transfer-open").click();
      return;
    }
    if (["F9", "F10", "F11"].includes(event.key)) {
      event.preventDefault();
      if (event.key === "F9") prefs.left = !prefs.left;
      if (event.key === "F10") prefs.right = !prefs.right;
      if (event.key === "F11")
        prefs.left = prefs.right = !(prefs.left || prefs.right);
      applyPreferences();
      persist();
    }
    if (!ctrl && event.key.toLowerCase() === "l") $("loop").click();
    if (!ctrl && event.key.toLowerCase() === "f" && snapshot?.selected)
      await command("asset.action", {
        action: "favorite",
        path: snapshot.selected.path,
      });
    if (!ctrl && event.key.toLowerCase() === "m" && snapshot?.selected)
      await command("asset.action", {
        action: "mark",
        path: snapshot.selected.path,
      });
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "a") {
      event.preventDefault();
      await command("selection.all");
      requestPage();
    }
    if (ctrl && event.key.toLowerCase() === "n") {
      event.preventDefault();
      await command("tab.action", {
        action: "new",
        duplicateId: event.shiftKey ? snapshot.activeTab : undefined,
      });
    }
    if (ctrl && event.key.toLowerCase() === "w") {
      event.preventDefault();
      await command("tab.action", { action: "close", id: snapshot.activeTab });
    }
    if (ctrl && event.key === "Tab") {
      event.preventDefault();
      const index = snapshot.tabs.findIndex(
        (tab) => tab.id === snapshot.activeTab,
      );
      const next =
        (index + (event.shiftKey ? -1 : 1) + snapshot.tabs.length) %
        snapshot.tabs.length;
      await command("tab.action", {
        action: "activate",
        id: snapshot.tabs[next].id,
      });
    }
    if (event.key === "Enter" && snapshot?.enterInsertShortcuts) {
      event.preventDefault();
      if (snapshot.selectedCount > 1)
        await command("asset.action", { action: "stack" });
      else
        await command("insert", { newTrack: event.ctrlKey || event.metaKey });
    }
    if (["ArrowUp", "ArrowDown"].includes(event.key) && snapshot?.selected) {
      event.preventDefault();
      const index = await command("selection.move", {
        direction: event.key === "ArrowDown" ? 1 : -1,
        shift: event.shiftKey,
      });
      if (index) {
        const scroll = $("result-scroll");
        const top = (index - 1) * prefs.rowHeight;
        if (
          top < scroll.scrollTop ||
          top + prefs.rowHeight > scroll.scrollTop + scroll.clientHeight
        )
          scroll.scrollTop = Math.max(0, top - scroll.clientHeight / 2);
        await requestPage();
      }
    }
  }),
);
const resizeObserver = new ResizeObserver(() => {
  drawDetail();
  requestPage();
});
resizeObserver.observe($("detail-wave-wrap"));
resizeObserver.observe($("result-scroll"));
window.addEventListener("resize", () => {
  applyPreferences();
  requestPage();
});
window.addEventListener("beforeunload", () => {
  localizer.close();
  clearTimeout(suggestionTimer);
  clearTimeout(pageRetry);
  clearTimeout(waveRetry);
  clearTimeout(fxTimer);
  persist();
  host?.close();
  for (const pending of thumbnailCache.values())
    pending.then((url) => {
      if (url) URL.revokeObjectURL(url);
    });
  thumbnailCache.clear();
});

async function receiveFolderDrop(payload) {
  if (!payload.files?.length) return;
  const target = document
    .elementFromPoint(payload.x, payload.y)
    ?.closest("[data-library-id]");
  if (target || payload.files.length === 1) {
    await command("library.drop", {
      paths: payload.files,
      libraryId: target?.dataset.libraryId,
      separate: true,
    });
    return;
  }
  const dialog = node("dialog");
  dialog.append(node("h2", null, "导入文件夹"));
  for (const [label, separate] of [
    ["各自建立音效库", true],
    ["合并到一个音效库", false],
  ]) {
    const button = node("button", null, label);
    button.onclick = action(async () => {
      dialog.close();
      await command("library.drop", { paths: payload.files, separate });
    });
    dialog.append(button);
  }
  const cancel = node("button", null, "取消");
  cancel.onclick = () => dialog.close();
  dialog.append(cancel);
  dialog.onclose = () => dialog.remove();
  document.body.append(dialog);
  dialog.showModal();
}

for (const [id, name] of [
  ["left-toggle", "menu"],
  ["right-toggle", "panel"],
  ["settings-open", "settings"],
  ["layout-menu", "columns"],
  ["columns-open", "columns"],
])
  $(id).replaceChildren(icon(name));
for (const button of document.querySelectorAll("[data-rail]"))
  button.replaceChildren(
    icon(
      {
        libraries: "folder",
        all: "list",
        favorites: "star",
        previewed: "clock",
        ucs: "tag",
        collections: "layers",
        settings: "settings",
      }[button.dataset.rail],
    ),
  );
applyPreferences();
try {
  host = await connectHost();
  if (host.session.version) {
    $("app-version").textContent = host.session.version;
    document.title = `PsyReaSFX ${host.session.version}`;
  }
  $("host-label").textContent =
    host.session.host === "reaper" ? "REAPER · 已连接" : "Desktop · 已连接";
  if (host.runtime) {
    $("host-label").textContent =
      `ReaWebAPI ${host.runtime.version} · ${host.runtime.status === "external_unverified" ? "外部版本" : "候选基线"}`;
    $("host-label").title = host.runtime.notice;
  }
  if (host.subscribeDrops)
    host
      .subscribeDrops((payload) => receiveFolderDrop(payload).catch(report))
      .catch((error) => {
        $("add-library").title =
          `拖入文件夹暂不可用，可点击添加来源。${error.message}`;
      });
  host.addEventListener("state", (event) => applySnapshot(event.detail));
  if (host.state) applySnapshot(host.state);
} catch (error) {
  $("host-label").textContent = "宿主未连接";
  $("result-count").textContent = "等待宿主";
  report(error);
}
