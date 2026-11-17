// A single import action after database selection; all work stays in the host.
export async function openSoundminerImport(command) {
  if (document.querySelector(".soundminer-dialog")) return;
  const el = (tag, text, className) => {
    const element = document.createElement(tag);
    if (text !== undefined) element.textContent = text;
    if (className) element.className = className;
    return element;
  };
  const dialog = el("dialog", undefined, "soundminer-dialog");
  const title = el("h2", "导入 Soundminer 音效库");
  const help = el("p", "读取本机 Soundminer 数据库及波形缓存。请先关闭 Soundminer。原数据库和音频保持只读。", "muted");
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
      status.textContent = "已识别 Soundminer 素材库。重复素材保留已有元数据；离线路径仍会导入。";
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
      status.textContent = "已识别 Soundminer 素材库。重复素材保留已有元数据；离线路径仍会导入。";
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
    el("p", "将原路径前缀替换为本机路径，例如 /Volumes/SFX → D:/SFX；目录内的相对路径保持不变。", "muted"),
    row("Soundminer 原音频路径", oldPrefix), row("本机音频路径", newPrefix));
  const actions = el("div", undefined, "action-row");
  actions.append(start, cancel);
  dialog.append(title, help, row("检测到的音效库", select), row("数据库路径", databaseRow),
    sample, mapping, row("Soundminer 波形缓存路径", cache), waveLabel, status, actions);
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
