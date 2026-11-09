import { connectHost } from "./host.js";

const $ = (id) => document.getElementById(id);
const defaults = {
  version: 1,
  theme: "dark",
  left: false,
  right: true,
  leftWidth: 206,
  rightWidth: 290,
  auditionHeight: 282,
  rowHeight: 29,
  fontSize: 13,
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

let host;
let snapshot;
let page;
let pageSequence = 0;
let pageRequestActive = false;
let pageRequestAgain = false;
let waveSequence = 0;
let detailWave;
let inspectorTab = "metadata";
let inspectorPath;
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
  prefs.auditionHeight = clamp(
    prefs.auditionHeight,
    160,
    Math.max(160, innerHeight - 270),
  );
  prefs.rowHeight = clamp(prefs.rowHeight, 24, 44);
  prefs.fontSize = clamp(prefs.fontSize, 11, 18);
  document.body.dataset.theme = prefs.theme === "paper" ? "paper" : "dark";
  document.body.classList.toggle("left-hidden", !prefs.left);
  document.body.classList.toggle("right-hidden", !prefs.right);
  const style = document.documentElement.style;
  style.setProperty("--sidebar-left", `${prefs.leftWidth}px`);
  style.setProperty("--sidebar-right", `${prefs.rightWidth}px`);
  style.setProperty("--audition-height", `${prefs.auditionHeight}px`);
  style.setProperty("--row-height", `${prefs.rowHeight}px`);
  style.setProperty("--font-size", `${prefs.fontSize}px`);
  $("fx-panel").open = prefs.fx;
  $("fx-toggle").setAttribute("aria-expanded", String(prefs.fx));
  $("left-toggle").setAttribute("aria-expanded", String(prefs.left));
  $("right-toggle").setAttribute("aria-expanded", String(prefs.right));
  renderColumns();
  renderRows();
  requestAnimationFrame(drawDetail);
}

function visibleColumns() {
  return columnDefinitions.filter(([key]) => prefs.columns[key]);
}

function width(key) {
  return clamp(
    prefs.widths[key] ?? defaults.widths[key],
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
    const height = Math.max(0.5, Math.min(1, peak) * (rect.height / 2 - 1));
    context.moveTo(x + 0.5, rect.height / 2 - height);
    context.lineTo(x + 0.5, rect.height / 2 + height);
  }
  context.stroke();
}

function renderRows() {
  if (!page) return;
  const fragment = document.createDocumentFragment();
  const waveCanvases = [];
  for (const asset of page.items) {
    const selected = asset.selected || snapshot?.selected?.path === asset.path;
    const row = node("div", `result-row${selected ? " selected" : ""}`);
    row.dataset.path = asset.path;
    row.setAttribute("role", "row");
    row.setAttribute("aria-selected", String(Boolean(selected)));
    row.title = `${asset.name}\n${asset.description || asset.path}`;
    row.onclick = action((event) => selectAsset(asset, event));
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
        waveCanvases.push([canvas, asset.waveform, selected]);
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
  requestAnimationFrame(() => {
    const color = getComputedStyle(document.body)
      .getPropertyValue("--text")
      .trim();
    for (const [canvas, wave, selected] of waveCanvases)
      drawPeaks(canvas, wave, color, selected);
  });
}

async function selectAsset(asset, event = {}, autoPlay) {
  await command("selection.set", {
    index: asset.index,
    path: asset.path,
    revision: page.revision,
    ctrl: event.ctrlKey || event.metaKey || false,
    shift: event.shiftKey || false,
    autoPlay,
  });
  for (const item of page.items) item.selected = item.path === asset.path;
  renderRows();
}

async function requestPage() {
  if (!host || snapshot?.startup) return;
  if (pageRequestActive) {
    pageRequestAgain = true;
    return;
  }
  pageRequestActive = true;
  const sequence = ++pageSequence;
  const offset = Math.max(
    0,
    Math.floor($("result-scroll").scrollTop / prefs.rowHeight) - 6,
  );
  const limit = Math.min(
    100,
    Math.ceil($("result-scroll").clientHeight / prefs.rowHeight) + 18,
  );
  try {
    const result = await command("catalog.page", {
      offset,
      limit: Math.max(1, limit),
      waveforms: prefs.columns.waveform,
    });
    if (sequence !== pageSequence) return;
    page = result;
    $("result-space").style.height = `${result.total * prefs.rowHeight}px`;
    renderRows();
    clearTimeout(pageRetry);
    if (prefs.columns.waveform && result.items.some((asset) => !asset.waveform))
      pageRetry = setTimeout(requestPage, 650);
  } catch (error) {
    report(error);
  } finally {
    pageRequestActive = false;
    if (pageRequestAgain) {
      pageRequestAgain = false;
      requestPage();
    }
  }
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
    ...views.map(([view, label]) =>
      navItem(
        label,
        () => query({ view }),
        snapshot.view === view && !snapshot.libraryId && !snapshot.collectionId,
      ),
    ),
  );
  const libraries = [];
  for (const library of snapshot.libraries) {
    libraries.push(
      navItem(
        `▱ ${library.name}`,
        () => query({ libraryId: library.id }),
        snapshot.libraryId === library.id,
      ),
    );
    for (const root of snapshot.roots.filter(
      (root) => root.libraryId === library.id,
    )) {
      const item = navItem(
        root.path.split(/[\\/]/).filter(Boolean).pop() || root.path,
        () => query({ libraryId: library.id, root: root.path }),
        false,
        "root",
      );
      item.title = root.path;
      libraries.push(item);
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
      item.append(node("small", null, collection.count));
      return item;
    }),
  );
  const selectedScope = $("scope").value;
  $("scope").replaceChildren(
    new Option("全部音效库", ""),
    ...snapshot.libraries.map(
      (library) => new Option(library.name, library.id),
    ),
  );
  $("scope").value = snapshot.libraryId || selectedScope || "";
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
  snapshot = next;
  const ready = !next.startup;
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
  $("ai-more").hidden = !next.aiHasMore;
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
        })[name],
    );
  $("tasks-label").textContent = tasks.join(" · ");
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
    previous?.search !== next.search
  )
    $("search").value = next.search;
  if (
    ready &&
    (!previous || previous.startup || previous.revision !== next.revision)
  )
    requestPage();
  if (!previous || previous?.selected?.path !== next.selected?.path) {
    detailWave = null;
    zoomStart = 0;
    zoomEnd = 1;
    dirtyFields = {};
    originalFields = {};
    renderInspector();
    requestDetailWave();
    requestPage();
  } else if (
    next.selected &&
    !Object.keys(dirtyFields).length &&
    JSON.stringify(previous?.selected) !== JSON.stringify(next.selected)
  ) {
    renderInspector();
  }
  if (previous?.selectedCount !== next.selectedCount) requestPage();
  $("asset-name").textContent = next.selected?.name || "选择一个声音";
  $("asset-info").textContent = next.selected
    ? `${next.selected.channels} ch · ${Math.round(next.selected.sampleRate / 1000)} kHz · ${next.selected.bitDepth} bit · ${next.selected.library}`
    : "";
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
  drawDetail();
}

async function requestDetailWave() {
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
      points: 1024,
    });
    if (sequence !== waveSequence || snapshot?.selected?.path !== result.path)
      return;
    detailWave = result.waveform;
    drawDetail();
    if (!detailWave) waveRetry = setTimeout(requestDetailWave, 500);
  } catch (error) {
    report(error);
  }
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
  const canvas = $("detail-wave");
  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  const ratio = Math.min(devicePixelRatio || 1, 2);
  canvas.width = Math.round(rect.width * ratio);
  canvas.height = Math.round(rect.height * ratio);
  const context = canvas.getContext("2d");
  context.scale(ratio, ratio);
  const palette = getComputedStyle(document.body);
  const color = palette.getPropertyValue("--text").trim();
  const muted = palette.getPropertyValue("--muted").trim();
  const accent = palette.getPropertyValue("--accent").trim();
  const duration = snapshot?.selected?.duration || 0;
  $("wave-status").hidden = Boolean(detailWave);
  $("wave-status").textContent = snapshot?.selected
    ? "正在读取波形缓存…"
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
  context.fillStyle = accent;
  context.globalAlpha = 0.14;
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
  const channels = detailWave?.channels?.length
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
  context.strokeStyle = "#b8d6c3";
  context.beginPath();
  context.moveTo(xFor(snapshot.position || 0), top);
  context.lineTo(xFor(snapshot.position || 0), rect.height);
  context.stroke();
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

function renderInspector() {
  if (artworkUrl) {
    URL.revokeObjectURL(artworkUrl);
    artworkUrl = null;
  }
  const container = node("div", "inspector-content");
  const asset = snapshot?.selected;
  if (!asset) {
    container.append(node("p", "muted", "选择声音以查看详情"));
    $("inspector-body").replaceChildren(container);
    return;
  }
  inspectorPath = asset.path;
  container.append(node("h2", "selected-name", asset.name));
  if (inspectorTab === "metadata") {
    if (asset.artwork_path && asset.artwork_path !== "-") {
      const image = node("img", "artwork-cover");
      image.alt = asset.library || "音效库封面";
      image.hidden = true;
      container.append(image);
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
    const previousOriginal = originalFields;
    originalFields = {};
    for (const [key, label, multiline] of [
      ["description", "描述", true],
      ["keywords", "关键词", true],
      ["category", "Category"],
      ["subcategory", "Subcategory"],
      ["catid", "CatID"],
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
        input.title = "字段较长，当前显示摘要。完整内容由原元数据编辑器处理。";
      }
      input.oninput = () => {
        dirtyFields[key] = input.value;
      };
      container.append(wrapper);
    }
    const save = node("button", null, "保存元数据");
    save.disabled = snapshot.readOnly;
    save.onclick = action(async () => {
      await command("metadata.save", {
        path: inspectorPath,
        original: originalFields,
        values: dirtyFields,
      });
      dirtyFields = {};
      requestPage();
    });
    const reveal = node("button", null, "显示文件");
    reveal.onclick = action(() => host.reveal(asset.path));
    const actions = node("div", "action-row");
    actions.append(save, reveal);
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
    add.onclick = action(() => command("region.action", { action: "save" }));
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
  for (const [key, label] of [
    ["transfer_dir", "输出目录"],
    ["transfer_template", "文件名模板"],
  ]) {
    const [wrapper, input] = field(label, key, settings[key]);
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
        ["wav32", "WAV 32 bit float"],
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
    select.value = settings[key];
    wrapper.append(select);
    container.append(wrapper);
    controls[key] = select;
  }
  const submit = node("button", null, "导出所选声音");
  submit.onclick = action(() =>
    command(
      "transfer.start",
      Object.fromEntries(
        Object.entries(controls).map(([key, input]) => [key, input.value]),
      ),
    ),
  );
  container.append(
    submit,
    node("p", "muted", "导出使用 FX 参数与当前波形选区。源文件保持完整。"),
  );
}

function popover(anchor, content) {
  const pop = $("popover");
  pop.replaceChildren(...content);
  const rect = anchor.getBoundingClientRect();
  pop.style.left = `${Math.max(8, Math.min(rect.left, innerWidth - 290))}px`;
  pop.style.top = `${Math.min(rect.bottom + 5, innerHeight - 320)}px`;
  pop.showPopover();
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
  for (const [key, label] of columnDefinitions) {
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
  popover(anchor, content);
}

function rowMenu(event, asset) {
  const content = [node("h3", null, asset.name)];
  for (const [label, callback] of [
    [
      asset.favorite ? "取消收藏" : "收藏",
      () => command("favorite.toggle", { path: asset.path }),
    ],
    [
      "查找相似声音",
      async () => {
        await selectAsset(asset, {}, false);
        await command("search.similar", { scope: "all" });
      },
    ],
    ["显示文件", () => host.reveal(asset.path)],
  ]) {
    const item = node("button", "menu-item", label);
    item.onclick = action(async () => {
      $("popover").hidePopover();
      await callback();
      requestPage();
    });
    content.push(item);
  }
  const anchor = {
    getBoundingClientRect: () => ({
      left: event.clientX,
      bottom: event.clientY,
    }),
  };
  popover(anchor, content);
}

async function settingsDialog() {
  const body = $("settings-body");
  body.replaceChildren(node("p", "muted", "正在读取设置…"));
  if (!$("settings-dialog").open) $("settings-dialog").showModal();
  let settings;
  try {
    settings = await command("settings.get");
  } catch (error) {
    body.replaceChildren(node("p", "error", error.message));
    const retry = node("button", null, "重新读取设置");
    retry.type = "button";
    retry.onclick = action(settingsDialog);
    body.append(retry);
    return;
  }
  if (!$("settings-dialog").open) return;
  body.replaceChildren(node("h3", null, "显示"));
  if (host.runtime) {
    body.prepend(
      node(
        "p",
        "muted",
        `ReaWebAPI ${host.runtime.version} · ${host.runtime.notice}`,
      ),
    );
  }
  for (const [label, key, minimum, maximum] of [
    ["字号", "fontSize", 11, 18],
    ["列表行高", "rowHeight", 24, 44],
  ]) {
    const row = node("label", "setting-row", label);
    const input = node("input");
    input.type = "range";
    input.min = minimum;
    input.max = maximum;
    input.value = prefs[key];
    const output = node("output", null, prefs[key]);
    input.oninput = () => {
      prefs[key] = Number(input.value);
      output.value = input.value;
      applyPreferences();
      persist();
      requestPage();
    };
    row.append(input, output);
    body.append(row);
  }
  body.append(node("h3", null, "素材库维护"));
  const actions = node("div", "action-row");
  for (const [label, operation] of [
    ["扫描来源", "scan"],
    ["检查缺失", "missing"],
    ["检查重复", "duplicates"],
    ["校验缓存", "verify"],
    ["创建备份", "backup"],
    ["UCS 分类预览", "classify"],
    ["应用分类预览", "classifyApply"],
  ]) {
    const button = node("button", null, label);
    button.type = "button";
    button.onclick = action(() =>
      command("maintenance", { action: operation }),
    );
    actions.append(button);
  }
  body.append(
    actions,
    node(
      "p",
      "muted",
      "Alt + 按住列表行可拖出原文件。处理后的选区使用 Transfer 导出。",
    ),
  );
  body.append(
    toggle("监视已导入来源文件夹", settings.watch_enabled, (value) =>
      command("settings.watch", { enabled: value }).catch(report),
    ),
  );
  body.append(node("h3", null, "AI 语义搜索"));
  const preset = node("select");
  preset.append(
    ...(settings.ai_presets || []).map(
      (item) => new Option(item.name, item.id),
    ),
  );
  preset.value = settings.ai_active_preset_id || "";
  preset.onchange = action(async () => {
    await command("settings.ai", { action: "select", id: preset.value });
    await settingsDialog();
  });
  body.append(preset);
  const controls = {};
  for (const [key, label, value] of [
    ["name", "预设名称", settings.ai_preset_name],
    ["url", "API 地址", settings.ai_url],
    ["model", "模型", settings.ai_model],
    [
      "key",
      settings.ai_key_saved ? "API Key（已保存，留空复用）" : "API Key",
      "",
    ],
  ]) {
    const [wrapper, input] = field(label, key, value);
    if (key === "key") {
      input.type = "password";
      input.autocomplete = "off";
    }
    body.append(wrapper);
    controls[key] = input;
  }
  const provider = node("select");
  provider.append(
    new Option("DeepSeek", "deepseek"),
    new Option("OpenAI", "openai"),
    new Option("兼容服务", "custom"),
  );
  provider.value = settings.ai_provider || "custom";
  body.append(provider);
  const aiActions = node("div", "action-row");
  for (const [title, operation] of [
    ["新建预设", "new"],
    ["保存预设", "save"],
    ["测试连接", "test"],
  ]) {
    const button = node("button", null, title);
    button.type = "button";
    button.onclick = action(async () => {
      const values = Object.fromEntries(
        Object.entries(controls).map(([key, input]) => [key, input.value]),
      );
      try {
        await command("settings.ai", {
          action: operation,
          provider: provider.value,
          ...values,
        });
      } finally {
        controls.key.value = "";
      }
      if (operation !== "test") await settingsDialog();
    });
    aiActions.append(button);
  }
  body.append(aiActions);
}

$("search-form").onsubmit = action((event) => {
  event.preventDefault();
  return query({ libraryId: $("scope").value });
});
$("scope").onchange = action(() => query({ libraryId: $("scope").value }));
$("ai-search").onclick = action(() =>
  command("search.ai", { query: $("search").value }),
);
$("ai-more").onclick = action(() => command("search.more"));
$("result-scroll").onscroll = () => {
  $("column-head").scrollLeft = $("result-scroll").scrollLeft;
  requestPage();
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
  prefs.fx = $("fx-panel").open;
  $("fx-toggle").setAttribute("aria-expanded", String(prefs.fx));
  persist();
  drawDetail();
};
$("new-tab").onclick = action(() => command("tab.action", { action: "new" }));
$("play").onclick = action(() => command("preview.play"));
$("stop").onclick = action(() => command("preview.stop"));
$("loop").onclick = action(() =>
  command("preview.parameters", { loop: !snapshot?.fx.loop }),
);
$("auto-preview").onchange = action(() =>
  command("preview.parameters", { auto_preview: $("auto-preview").checked }),
);
$("insert").onclick = action(() => command("insert"));
$("similar-search").onclick = action(() =>
  command("search.similar", { scope: "all" }),
);
$("save-region").onclick = action(() =>
  command("region.action", { action: "save" }),
);
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
$("new-collection").onclick = action(() =>
  command("collection.create", { kind: "project" }),
);
$("ucs-directory").ontoggle = action(async () => {
  if (!$("ucs-directory").open || $("ucs-categories").childElementCount) return;
  const categories = await command("catalog.ucs");
  const fragment = document.createDocumentFragment();
  for (const category of categories) {
    const details = node("details");
    details.append(
      node("summary", "section-label", category.label || category.name),
    );
    const all = navItem(
      `全部 ${category.name}`,
      () => query({ category: category.name }),
      false,
    );
    details.append(all);
    for (const entry of category.entries)
      details.append(
        navItem(
          `${entry.catid} · ${entry.label || entry.name}`,
          () => query({ catid: entry.catid }),
          false,
          "root",
        ),
      );
    fragment.append(details);
  }
  $("ucs-categories").append(fragment);
});
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
  const create = node("button", "menu-item", "＋ 新建项目素材箱");
  create.onclick = action(() =>
    command("collection.create", { kind: "project" }),
  );
  content.push(create);
  popover($("collection-menu"), content);
};
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
function wavePercent(event) {
  const rect = detailCanvas.getBoundingClientRect();
  return clamp(
    zoomStart +
      ((event.clientX - rect.left) / rect.width) * (zoomEnd - zoomStart),
    0,
    1,
  );
}
detailCanvas.onpointerdown = (event) => {
  if (event.button !== 0 || !snapshot?.selected) return;
  regionDrag = { start: wavePercent(event), current: wavePercent(event) };
  detailCanvas.setPointerCapture(event.pointerId);
};
detailCanvas.onpointermove = (event) => {
  if (!regionDrag) return;
  regionDrag.current = wavePercent(event);
  drawDetail();
  updateReadouts();
};
detailCanvas.onpointerup = action(async () => {
  if (!regionDrag) return;
  const start = Math.min(regionDrag.start, regionDrag.current);
  const finish = Math.max(regionDrag.start, regionDrag.current);
  regionDrag = null;
  await command("preview.region", { start, finish });
});
detailCanvas.onpointercancel = () => {
  regionDrag = null;
  drawDetail();
};
detailCanvas.ondblclick = action((event) =>
  command("preview.play", { position: wavePercent(event), selection: false }),
);
detailCanvas.onwheel = (event) => {
  event.preventDefault();
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
document.addEventListener(
  "keydown",
  action(async (event) => {
    if (event.target.closest("input,textarea,select,dialog") || !host) return;
    if (event.code === "Space") {
      event.preventDefault();
      await command(snapshot?.playing ? "preview.stop" : "preview.play");
    }
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "a") {
      event.preventDefault();
      await command("selection.all");
      requestPage();
    }
    if (event.key === "Enter") {
      event.preventDefault();
      await command("insert");
    }
    if (["ArrowUp", "ArrowDown"].includes(event.key) && snapshot?.selected) {
      event.preventDefault();
      const index =
        (snapshot.selected.index ||
          page?.items.find((asset) => asset.path === snapshot.selected.path)
            ?.index ||
          1) + (event.key === "ArrowDown" ? 1 : -1);
      const asset = page?.items.find((item) => item.index === index);
      if (asset) await selectAsset(asset, {}, true);
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
  clearTimeout(pageRetry);
  clearTimeout(waveRetry);
  clearTimeout(fxTimer);
  persist();
  host?.close();
});

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
  host.addEventListener("state", (event) => applySnapshot(event.detail));
  if (host.state) applySnapshot(host.state);
} catch (error) {
  $("host-label").textContent = "宿主未连接";
  $("result-count").textContent = "等待宿主";
  report(error);
}
