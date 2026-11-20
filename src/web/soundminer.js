const el = (tag, text, className) => {
  const element = document.createElement(tag);
  if (text !== undefined) element.textContent = text;
  if (className) element.className = className;
  return element;
};

export async function openSoundminerCatalogs(command) {
  if (document.querySelector(".soundminer-dialog")) return;
  const dialog = el("dialog", undefined, "soundminer-dialog");
  const status = el("p", "正在读取独立库列表…", "soundminer-status");
  status.setAttribute("role", "status");
  const list = el("div", undefined, "soundminer-catalogs");
  const close = el("button", "关闭");
  close.onclick = () => dialog.close();
  const add = el("button", "导入 Soundminer 音效库", "primary");
  add.onclick = () => { dialog.close(); dialog.remove(); openSoundminerImport(command); };
  const actions = el("div", undefined, "action-row");
  actions.append(add, close);
  dialog.append(el("h2", "选择独立库"),
    el("p", "每个库独立保存素材、设置和缓存。选择后打开对应窗口；已打开的库会切到前台。", "muted"),
    list, status, actions);
  dialog.onclose = () => dialog.remove();
  document.body.append(dialog);
  dialog.showModal();
  try {
    const result = await command("soundminer.catalog.list");
    if (!dialog.isConnected) return;
    status.textContent = "";
    for (const catalog of result.catalogs) {
      const row = el("div", undefined, "soundminer-catalog");
      const info = el("div");
      info.append(el("strong", catalog.kind === "prs" ? "PRS 原有库" : `Soundminer · ${catalog.name}`));
      if (catalog.path) info.append(el("p", catalog.path, "path-label muted"));
      const current = catalog.id === result.current;
      const open = el("button", current ? "当前库" : "打开");
      open.disabled = current;
      open.onclick = async () => {
        open.disabled = true;
        try {
          await command("soundminer.catalog.activate", { id: catalog.id });
          dialog.close();
        } catch (error) {
          status.textContent = String(error.message || error);
          open.disabled = false;
        }
      };
      row.append(info, open);
      if (current && catalog.kind === "soundminer") {
        const resume = el("button", "继续导入");
        resume.title = "补全取消或失败的导入，保留此独立库中已导入的素材";
        resume.onclick = async () => {
          resume.disabled = true;
          try {
            await command("soundminer.catalog.resume");
            dialog.close();
          } catch (error) {
            status.textContent = String(error.message || error);
            resume.disabled = false;
          }
        };
        open.replaceWith(resume);
      }
      list.append(row);
    }
  } catch (error) { status.textContent = String(error.message || error); }
}

// A single import action opens the source's isolated catalog in its own host instance.
export async function openSoundminerImport(command) {
  if (document.querySelector(".soundminer-dialog")) return;
  const dialog = el("dialog", undefined, "soundminer-dialog");
  const title = el("h2", "导入 Soundminer 音效库");
  const help = el("p", "在独立库中读取 Soundminer 数据库及波形缓存，导入后打开对应窗口。可与 Soundminer 同时运行；数据库正在写入时暂停本次导入。", "muted");
  const status = el("p", "正在查找 Soundminer 音效库…", "soundminer-status");
  status.setAttribute("role", "status");
  const select = el("select");
  select.setAttribute("aria-label", "Soundminer 音效库");
  const databasePath = el("input");
  databasePath.setAttribute("aria-label", "数据库路径");
  databasePath.placeholder = ".sqlite";
  const sample = el("p", "", "path-label");
  const cache = el("input");
  cache.setAttribute("aria-label", "Soundminer 波形缓存路径");
  cache.placeholder = "waveforms.sqlite";
  const oldPrefix = el("input");
  oldPrefix.setAttribute("aria-label", "Soundminer 原音频路径");
  const newPrefix = el("input");
  newPrefix.setAttribute("aria-label", "本机音频路径");
  oldPrefix.oninput = newPrefix.oninput = () => {
    if (Boolean(oldPrefix.value.trim()) === Boolean(newPrefix.value.trim()))
      status.textContent = "已识别 Soundminer 素材库。与 PRS 原有库独立保存和加载；离线路径仍会导入。";
  };
  const waveforms = el("input");
  waveforms.type = "checkbox";
  waveforms.checked = true;
  const waveLabel = el("label", undefined, "soundminer-checkbox");
  waveLabel.append(waveforms, el("span", "复用兼容的波形缓存"));
  let inspecting = 0;
  let busy = false;
  const start = el("button", "一键导入");
  start.type = "button";
  start.className = "primary";
  const cancel = el("button", "关闭");
  cancel.type = "button";
  cancel.onclick = () => dialog.close();
  const row = (label, input) => {
    const wrapper = el("label", undefined, "soundminer-field");
    wrapper.append(el("span", label), input);
    return wrapper;
  };
  const inspect = async (path) => {
    const generation = ++inspecting;
    start.disabled = true;
    databasePath.value = path;
    status.textContent = "正在读取 Soundminer 音效库…";
    sample.textContent = "";
    try {
      const info = await command("soundminer.inspect", { path });
      if (!dialog.isConnected || inspecting !== generation) return;
      cache.value = info.cachePath || "";
      sample.textContent = (info.samples || []).join("\n");
      status.textContent = "已识别 Soundminer 素材库。与 PRS 原有库独立保存和加载；离线路径仍会导入。";
      start.disabled = false;
    } catch (error) {
      if (dialog.isConnected && inspecting === generation)
        status.textContent = String(error.message || error);
    }
  };
  select.onchange = () => inspect(select.value);
  databasePath.onchange = () => inspect(databasePath.value.trim());
  databasePath.oninput = () => {
    inspecting++;
    start.disabled = true;
  };
  const browse = el("button", "浏览…");
  browse.type = "button";
  browse.onclick = async () => {
    try {
      const path = await command("soundminer.choose");
      if (path && dialog.isConnected) await inspect(path);
    } catch (error) { status.textContent = String(error.message || error); }
  };
  const databaseRow = el("div", undefined, "path-control");
  databaseRow.append(databasePath, browse);
  const mapping = el("details");
  mapping.append(el("summary", "音频已换盘或来自 Mac？设置路径映射"),
    el("p", "PRS 会自动读取 Soundminer 已启用的实时路径映射。需要单独指定时，在下方填写原目录和本机目录。", "muted"),
    row("Soundminer 原音频路径", oldPrefix), row("本机音频路径", newPrefix));
  const actions = el("div", undefined, "action-row");
  actions.append(start, cancel);
  dialog.append(title, help, row("检测到的音效库", select), row("数据库路径", databaseRow),
    sample, mapping, row("Soundminer 波形缓存路径", cache), waveLabel,
    el("p", "已有独立库会直接打开；需要补全时，从“选择独立库”点击“继续导入”。", "muted"),
    status, actions);
  dialog.onclose = () => { inspecting++; dialog.remove(); };
  start.onclick = async () => {
    if (busy) return;
    if (Boolean(oldPrefix.value.trim()) !== Boolean(newPrefix.value.trim())) {
      status.textContent = "路径映射需要同时填写原路径和新路径";
      return;
    }
    busy = true;
    start.disabled = true;
    try {
      await command("soundminer.import", {
        path: databasePath.value.trim(), cachePath: cache.value.trim(),
        oldPrefix: oldPrefix.value.trim(), newPrefix: newPrefix.value.trim(), waveforms: waveforms.checked,
      });
      dialog.close();
    } catch (error) {
      status.textContent = String(error.message || error);
      start.disabled = false;
    } finally { busy = false; }
  };
  start.disabled = true;
  document.body.append(dialog);
  dialog.showModal();
  const discoveryGeneration = inspecting;
  try {
    const libraries = await command("soundminer.discover");
    if (!dialog.isConnected) return;
    for (const library of libraries) {
      const option = el("option", `${library.name} · ${library.version}`);
      option.value = library.path;
      select.append(option);
    }
    if (libraries.length && inspecting === discoveryGeneration) await inspect(libraries[0].path);
    else {
      select.disabled = true;
      status.textContent = "未检测到本机 Soundminer 库，请浏览选择数据库文件。";
    }
  } catch (error) { status.textContent = String(error.message || error); }
}
