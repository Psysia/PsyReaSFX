// Settings owns its draft and DOM. Playback snapshots must never rebuild an editor.
const el = (tag, className, text) => {
  const item = document.createElement(tag);
  if (className) item.className = className;
  if (text !== undefined) item.textContent = text;
  return item;
};
const pages = [
  ["general", "常规与插入", "浏览行为、后台监视与 REAPER 插入"],
  ["appearance", "外观与布局", "字体、主题、面板和试听颜色"],
  ["waveform", "波形与分析", "波形精度、瞬态、响度与缓存"],
  ["libraries", "音效库与来源", "管理音效库、来源文件夹与封面"],
  ["collections", "集合与搜索", "播放列表、工程素材箱与保存的搜索"],
  ["transfer", "Transfer 交付", "输出格式、命名、处理与交付动作"],
  ["ai", "AI 语义搜索", "连接服务商并管理独立预设"],
  ["maintenance", "维护与恢复", "检查素材、分类、备份与任务"],
  ["about", "帮助与诊断", "快捷键、运行环境与诊断信息"],
];
const groupPage = {
  常规: "general",
  外观: "appearance",
  试听颜色: "appearance",
  波形与分析: "waveform",
  Transfer: "transfer",
  维护: "maintenance",
};
const operationLabels = {
  add: "添加来源",
  rename: "重命名",
  scan: "扫描",
  remove: "移除",
  relink: "重新链接",
  artwork: "指定封面",
  redetectArtwork: "重新发现封面",
  clearArtwork: "清除封面",
  addSelection: "加入所选素材",
  removeSelection: "移除所选素材",
  bind: "绑定当前工程",
  overwrite: "用当前条件覆盖",
  activate: "打开",
};

export function createSettings({
  dialog,
  command,
  getPreferences,
  setPreferences,
  defaults,
  getHost,
  getSnapshot,
  afterChange,
  renderReview,
  manage,
  createCollection,
}) {
  let generation = 0;
  let settings,
    draft = {},
    localDraft = {},
    localOriginal = {},
    section = "general";
  let filter = "",
    busy = false,
    loaded = false,
    aiDraft = null,
    aiUnsaved = false;
  const body = dialog.querySelector("#settings-body");
  const status = dialog.querySelector("#dialog-status");
  const apply = dialog.querySelector("#settings-apply");
  const nav = dialog.querySelector("#settings-nav");
  const search = dialog.querySelector("#settings-search");
  const discard = dialog.querySelector("#settings-discard");
  const close = dialog.querySelector("#settings-close");
  const changed = () =>
    Object.keys(draft).length > 0 ||
    JSON.stringify(localDraft) !== JSON.stringify(localOriginal);
  function message(text, error = false) {
    status.textContent = text;
    status.classList.toggle("error", error);
  }
  function updateDirty() {
    apply.disabled = !loaded || busy || settings?.loading || !changed();
    discard.hidden = !changed() && !aiUnsaved;
    if (!busy)
      message(
        settings?.loading
          ? "素材库正在加载，设置将在加载完成后可用"
          : changed()
            ? "有未保存的更改"
            : aiUnsaved
              ? "AI 预设有未保存的更改"
              : "所有更改已保存",
      );
  }
  async function run(callback) {
    if (busy) return;
    busy = true;
    apply.disabled = true;
    dialog.setAttribute("aria-busy", "true");
    try {
      return await callback();
    } catch (error) {
      message(error.message || String(error), true);
    } finally {
      busy = false;
      dialog.removeAttribute("aria-busy");
      apply.disabled = !loaded || settings?.loading || !changed();
    }
  }
  function button(label, callback, className = "") {
    const item = el("button", className, label);
    item.type = "button";
    item.onclick = () => run(callback);
    return item;
  }
  function card(title, description, target = body) {
    const item = el("section", "settings-card");
    item.append(el("h3", null, title));
    if (description) item.append(el("p", "muted", description));
    target.append(item);
    return item;
  }
  function actions(target, definitions, method = "records.action") {
    const row = el("div", "action-row");
    for (const [label, action] of definitions)
      row.append(
        button(label, async () => {
          await command(method, { action });
          message("操作已提交，可在底部任务栏查看进度");
          afterChange();
        }),
      );
    target.append(row);
  }
  function setDraft(key, value) {
    if (value === settings.values[key]) delete draft[key];
    else draft[key] = value;
    updateDirty();
  }
  function control(definition, value, onChange, local = false) {
    const row = el(
      "label",
      `setting-control${definition.kind === "boolean" ? " switch-row" : ""}`,
    );
    const caption = el("span", "setting-caption", definition.label);
    if (definition.description)
      caption.append(el("small", null, definition.description));
    row.append(caption);
    const input = el(definition.kind === "choice" ? "select" : "input");
    input.dataset[local ? "preference" : "setting"] = definition.key;
    input.setAttribute("aria-label", definition.label);
    if (definition.kind === "choice") {
      for (const option of definition.options) {
        const [key, label] = Array.isArray(option)
          ? option
          : [
              option,
              definition.key === "language"
                ? { zh: "简体中文", en: "English" }[option]
                : option,
            ];
        input.append(new Option(label, key));
      }
    } else
      input.type =
        { boolean: "checkbox", number: "number", color: "color" }[
          definition.kind
        ] || "text";
    if (definition.kind === "boolean") input.checked = Boolean(value);
    else input.value = value ?? "";
    if (definition.kind === "number") {
      input.min = definition.minimum;
      input.max = definition.maximum;
      input.step = definition.integer ? "1" : "any";
      input.required = true;
    }
    input.oninput = input.onchange = () => {
      if (!input.validity.valid) {
        message("请检查输入值的范围", true);
        return;
      }
      onChange(
        definition.kind === "boolean"
          ? input.checked
          : definition.kind === "number"
            ? Number(input.value)
            : input.value,
      );
    };
    row.append(input);
    return row;
  }
  function appearance() {
    const display = card(
      "工作区外观",
      "默认使用波形优先布局；调整面板不改变底部波形宽度。",
    );
    const definitions = [
      {
        key: "theme",
        label: "主题",
        kind: "choice",
        options: [
          ["dark", "暗黑"],
          ["paper", "纸白墨绿"],
        ],
      },
      { key: "fontFamily", label: "字体", kind: "string" },
      {
        key: "fontSize",
        label: "字号",
        kind: "number",
        minimum: 10,
        maximum: 24,
        integer: true,
      },
      {
        key: "rowHeight",
        label: "列表行高",
        kind: "number",
        minimum: 24,
        maximum: 52,
        integer: true,
      },
      { key: "left", label: "来源侧栏", kind: "boolean" },
      { key: "right", label: "检查器", kind: "boolean" },
      { key: "fx", label: "FX 面板", kind: "boolean" },
      {
        key: "leftWidth",
        label: "来源侧栏宽度",
        kind: "number",
        minimum: 140,
        maximum: 420,
        integer: true,
      },
      {
        key: "rightWidth",
        label: "检查器宽度",
        kind: "number",
        minimum: 220,
        maximum: 480,
        integer: true,
      },
      {
        key: "auditionHeight",
        label: "试听区域高度",
        kind: "number",
        minimum: 160,
        maximum: 700,
        integer: true,
      },
      { key: "accentColor", label: "强调色", kind: "color" },
      { key: "surfaceColor", label: "框架底色", kind: "color" },
    ];
    for (const definition of definitions)
      display.append(
        control(
          definition,
          localDraft[definition.key],
          (value) => {
            localDraft[definition.key] = value;
            updateDirty();
          },
          true,
        ),
      );
    display.append(
      button("恢复默认布局", () => {
        localDraft = structuredClone(defaults);
        render();
        updateDirty();
      }),
    );
    const navigation = card("导航模块", "选择左侧导航中显示的内容。");
    for (const [key, label] of [
      ["libraries", "音效库"],
      ["folders", "文件夹"],
      ["ucs", "UCS 分类"],
      ["collections", "集合"],
      ["saved", "保存的搜索"],
      ["workflow", "工作流筛选"],
    ]) {
      navigation.append(
        control(
          { key, label, kind: "boolean" },
          localDraft.navigation?.[key] !== false,
          (value) => {
            localDraft.navigation = { ...localDraft.navigation, [key]: value };
            updateDirty();
          },
          true,
        ),
      );
    }
    actions(card("试听记录"), [
      ["恢复上次试听标记", "restorePlayed"],
      ["清除本次试听标记", "clearPlayed"],
      ["清除保存的试听标记", "clearSavedPlayed"],
    ]);
  }
  async function management() {
    const target = card(
      section === "libraries" ? "音效库与来源" : "集合与搜索",
    );
    target.append(el("p", "muted", "正在读取…"));
    const current = generation;
    const groups = await command("management.get");
    if (!target.isConnected || current !== generation) return;
    target.lastChild.remove();
    for (const group of groups) {
      if (
        (section === "libraries") !==
        ["library", "root"].includes(group.kind)
      )
        continue;
      target.append(el("h4", null, group.label));
      if (!group.items.length) target.append(el("p", "muted", "暂无内容"));
      for (const item of group.items) {
        const row = el("article", "management-row");
        const name = el("strong", null, item.name);
        name.dataset.literal = "true";
        row.append(name);
        const options = el("div", "action-row");
        for (const operation of group.actions) {
          if (operation === "bind" && item.kind !== "project") continue;
          options.append(
            button(
              operationLabels[operation],
              async () => {
                const completed = await manage(group.kind, item, operation);
                if (completed !== false && target.isConnected) {
                  target.remove();
                  await management();
                  afterChange();
                }
              },
              operation === "remove" ? "danger-quiet" : "",
            ),
          );
        }
        row.append(options);
        target.append(row);
      }
    }
    const row = el("div", "action-row");
    if (section === "libraries")
      row.append(
        button("添加音效库", async () => {
          await command("library.add");
          target.remove();
          await management();
        }),
      );
    else {
      for (const [label, kind] of [
        ["新建播放列表", "playlist"],
        ["新建项目素材箱", "project"],
      ])
        row.append(
          button(label, async () => {
            await createCollection(kind);
            target.remove();
            await management();
          }),
        );
      row.append(
        button("保存当前搜索", async () => {
          await command("records.action", { action: "saveSearch" });
          target.remove();
          await management();
        }),
      );
    }
    target.append(row);
  }
  function ai() {
    const target = card(
      "AI 服务预设",
      "AI 仅扩展搜索词，素材召回在本地完成；不会上传音频。",
    );
    const presets = el("select");
    presets.setAttribute("aria-label", "AI 预设");
    for (const item of settings.ai_presets || []) {
      const option = new Option(item.name, item.id);
      option.dataset.literal = "true";
      presets.append(option);
    }
    presets.value = settings.ai_active_preset_id || "";
    const controls = {};
    if (!aiDraft)
      aiDraft = {
        name: settings.ai_preset_name || "",
        url: settings.ai_url || "",
        model: settings.ai_model || "",
        key: "",
        provider: settings.ai_provider || "custom",
      };
    const warning = el("p", "muted", "预设使用下方的保存按钮单独保存。");
    const dirtyAI = () => {
      aiUnsaved = true;
      warning.textContent = "预设有未保存的更改";
      updateDirty();
    };
    presets.onchange = () =>
      run(async () => {
        if (aiUnsaved) {
          presets.value = settings.ai_active_preset_id;
          message("请先保存当前 AI 预设", true);
          return;
        }
        await command("settings.ai", { action: "select", id: presets.value });
        settings = await command("settings.get");
        aiDraft = null;
        render();
      });
    target.append(presets);
    for (const [key, label, value, type] of [
      ["name", "预设名称", settings.ai_preset_name],
      ["url", "API 地址", settings.ai_url],
      ["model", "模型", settings.ai_model],
      [
        "key",
        settings.ai_key_saved ? "API Key（已保存，留空复用）" : "API Key",
        "",
        "password",
      ],
    ]) {
      const row = el("label", "field");
      row.append(el("span", null, label));
      const input = el("input");
      input.type = type || "text";
      input.value = aiDraft[key] ?? value ?? "";
      input.dataset.field = key;
      input.autocomplete = "off";
      input.oninput = () => {
        aiDraft[key] = input.value;
        dirtyAI();
      };
      row.append(input);
      target.append(row);
      controls[key] = input;
    }
    const provider = el("select");
    provider.setAttribute("aria-label", "服务商");
    provider.append(
      new Option("DeepSeek", "deepseek"),
      new Option("OpenAI", "openai"),
      new Option("兼容服务", "custom"),
    );
    provider.value = aiDraft.provider;
    provider.onchange = () => {
      aiDraft.provider = provider.value;
      dirtyAI();
    };
    target.append(provider);
    const row = el("div", "action-row");
    for (const [label, action] of [
      ["新建预设", "new"],
      ["保存预设", "save"],
      ["测试连接", "test"],
      ["删除当前预设", "delete"],
    ]) {
      row.append(
        button(
          label,
          async () => {
            if (aiUnsaved && ["new", "delete"].includes(action)) {
              message("请先保存当前 AI 预设", true);
              return;
            }
            const result = await command("settings.ai", {
              action,
              id: presets.value,
              provider: provider.value,
              ...Object.fromEntries(
                Object.entries(controls).map(([key, input]) => [
                  key,
                  input.value,
                ]),
              ),
            });
            if (result === false) return;
            if (action === "test") {
              message("正在测试连接，请查看下方结果");
              return;
            }
            controls.key.value = "";
            aiDraft = null;
            aiUnsaved = false;
            settings = await command("settings.get");
            render();
            message("预设已保存");
          },
          action === "save" ? "primary" : "",
        ),
      );
    }
    const result = el("p", "muted", settings.ai_status || "");
    result.id = "ai-connection-status";
    target.append(row, warning, result);
  }
  function extra() {
    if (section === "appearance") appearance();
    if (section === "ai") ai();
    if (["libraries", "collections"].includes(section))
      management().catch((error) => message(error.message, true));
    if (section === "waveform")
      actions(card("波形缓存", settings.wave_cache_dir || ""), [
        ["预生成波形", "precache"],
        ["预生成当前范围波形", "precacheCurrent"],
        ["取消波形预生成", "cancelPrecache"],
        ["更改波形缓存目录", "cacheFolder"],
        ["恢复默认缓存目录", "cacheDefault"],
        ["清理波形缓存", "clearWaveforms"],
        ["清理相似缓存", "clearSimilarity"],
      ]);
    if (section === "maintenance") {
      const summary = getSnapshot();
      card(
        "素材库状态",
        `${summary?.loaded?.toLocaleString() || 0} 个素材 · ${summary?.roots?.length || 0} 个来源`,
      );
      actions(
        card("检查与备份"),
        [
          ["扫描来源", "scan"],
          ["检查缺失", "missing"],
          ["检查重复", "duplicates"],
          ["校验缓存", "verify"],
          ["创建备份", "backup"],
        ],
        "maintenance",
      );
      actions(card("恢复与记录"), [
        ["确认重复文件", "verifyDuplicates"],
        ["恢复最近备份", "restoreBackup"],
        ["重试失败任务", "retryFailed"],
        ["重新发现封面", "clearArtwork"],
        ["打开数据目录", "dataFolder"],
        ["绑定当前工程素材箱", "currentProject"],
      ]);
      actions(
        card("UCS 自动分类"),
        [
          ["UCS 分类预览", "classify"],
          ["应用分类预览", "classifyApply"],
          ["丢弃分类预览", "classifyDiscard"],
        ],
        "maintenance",
      );
      const review = el("div");
      review.id = "classification-review";
      body.append(review);
      renderReview();
      const reset = card(
        "重置与恢复",
        "重建和恢复会再次确认，请先保存需要保留的更改。",
      );
      for (const [label, action] of [
        ["重置界面", "resetInterface"],
        ["重建数据库并保留来源", "resetDatabase"],
        ["恢复出厂设置", "factoryReset"],
      ])
        reset.append(
          button(
            label,
            async () => {
              await command("records.action", { action });
              if (action === "resetInterface") {
                setPreferences(structuredClone(defaults));
                localDraft = getPreferences();
                localOriginal = structuredClone(localDraft);
              }
              await reload();
            },
            "danger-quiet",
          ),
        );
    }
    if (section === "about") {
      const runtime = getHost()?.runtime;
      card("PsyReaSFX", `WebView · ${getHost()?.session?.version || "0.9.a"}`);
      if (runtime)
        card("运行环境", `ReaWebAPI ${runtime.version} · ${runtime.notice}`);
      const help = card("快捷键与使用说明");
      for (const [keys, description] of [
        ["Space", "播放 / 停止"],
        ["F / M / L", "收藏 / 标记 / 循环"],
        ["Ctrl+F", "搜索"],
        ["Ctrl+Shift+F", "AI 语义搜索"],
        ["Ctrl+N / Ctrl+Shift+N", "新建 / 复制标签"],
        ["Ctrl+W / Ctrl+Tab", "关闭 / 切换标签"],
        ["F9 / F10 / F11", "来源 / 检查器 / 专注模式"],
        ["Ctrl+T / Ctrl+R", "交付 / 扫描"],
        ["Enter / Ctrl+Enter", "插入 / 新轨插入（需在常规设置中启用）"],
        ["滚轮 / Shift+滚轮", "波形缩放 / 平移"],
        ["右键拖动波形", "擦播"],
        ["Alt+拖动列表行", "拖出原文件"],
      ]) {
        const row = el("div", "shortcut-row");
        row.append(el("kbd", null, keys), el("span", null, description));
        help.append(row);
      }
      help.append(
        button("复制诊断信息", async () => {
          await navigator.clipboard.writeText(await command("diagnostics.get"));
          message("诊断信息已复制");
        }),
      );
    }
  }
  function render() {
    body.replaceChildren();
    for (const item of nav.children) {
      item.classList.toggle(
        "active",
        item.dataset.section === section && !filter,
      );
      item.setAttribute(
        "aria-selected",
        String(item.dataset.section === section && !filter),
      );
    }
    const current = pages.find(([key]) => key === section);
    body.append(
      el("h2", null, filter ? "搜索设置" : current[1]),
      el("p", "settings-intro", filter ? "匹配设置名称或分类" : current[2]),
    );
    const groups = new Map();
    for (const definition of settings.schema || []) {
      if (
        filter
          ? !`${definition.label} ${definition.group} ${definition.key}`
              .toLocaleLowerCase()
              .includes(filter)
          : groupPage[definition.group] !== section
      )
        continue;
      let target = groups.get(definition.group);
      if (!target) {
        target = card(definition.group);
        groups.set(definition.group, target);
      }
      target.append(
        control(
          definition,
          draft[definition.key] ?? settings.values[definition.key],
          (value) => setDraft(definition.key, value),
        ),
      );
    }
    if (!filter) extra();
    else if (!groups.size) body.append(el("p", "muted", "没有匹配的设置"));
    if (
      section === "general" &&
      !filter &&
      !settings.schema?.some((item) => item.key === "watch_enabled")
    ) {
      card("后台监视").append(
        control(
          {
            key: "watch_enabled",
            label: "监视已导入来源文件夹",
            kind: "boolean",
          },
          draft.watch_enabled ?? settings.watch_enabled,
          (value) => setDraft("watch_enabled", value),
        ),
      );
    }
  }
  async function reload() {
    const current = ++generation;
    loaded = false;
    body.replaceChildren(el("div", "settings-loading", "正在读取设置…"));
    message("正在读取设置…");
    apply.disabled = true;
    try {
      const result = await command("settings.get");
      if (current !== generation || !dialog.open) return;
      settings = result;
      loaded = true;
      render();
      updateDirty();
    } catch (error) {
      if (current !== generation || !dialog.open) return;
      body.replaceChildren(
        el("p", "error", error.message),
        button("重新读取设置", reload),
      );
      message(error.message, true);
    }
  }
  for (const [key, title] of pages) {
    const item = el("button", "settings-nav-item", title);
    item.type = "button";
    item.dataset.section = key;
    item.setAttribute("role", "tab");
    item.onclick = () => {
      if (!loaded || busy) return;
      section = key;
      filter = "";
      search.value = "";
      render();
      body.scrollTop = 0;
    };
    nav.append(item);
  }
  search.oninput = () => {
    if (!loaded) return;
    filter = search.value.trim().toLocaleLowerCase();
    render();
  };
  dialog.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && event.target.matches("input"))
      event.preventDefault();
  });
  const requestClose = () => {
    if (busy) return;
    if (changed() || aiUnsaved) {
      discard.hidden = false;
      message("更改尚未保存。请保存更改，或点击“放弃更改”后关闭。", true);
      return;
    }
    dialog.close();
  };
  close.onclick = requestClose;
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    requestClose();
  });
  dialog.addEventListener("close", () => {
    generation++;
  });
  discard.onclick = () => {
    draft = {};
    aiDraft = null;
    aiUnsaved = false;
    localDraft = structuredClone(localOriginal);
    render();
    updateDirty();
  };
  apply.onclick = () =>
    run(async () => {
      for (const input of body.querySelectorAll("input"))
        if (!input.reportValidity()) return;
      if (Object.keys(draft).length)
        await command("settings.update", { values: draft });
      Object.assign(settings.values, draft);
      draft = {};
      setPreferences(structuredClone(localDraft));
      localOriginal = structuredClone(localDraft);
      discard.hidden = !aiUnsaved;
      afterChange();
      message(aiUnsaved ? "AI 预设有未保存的更改" : "所有更改已保存");
    });
  return {
    open(target = section) {
      if (dialog.open) return;
      section =
        typeof target === "string" && pages.some(([key]) => key === target)
          ? target
          : section;
      draft = {};
      aiDraft = null;
      aiUnsaved = false;
      localOriginal = getPreferences();
      localDraft = structuredClone(localOriginal);
      filter = "";
      search.value = "";
      dialog.showModal();
      return reload();
    },
    update(snapshot) {
      if (dialog.open && loaded && settings.loading && !snapshot.startup)
        reload();
      const result = dialog.querySelector("#ai-connection-status");
      if (result && snapshot.aiConnectionStatus)
        result.textContent = snapshot.aiConnectionStatus;
    },
  };
}
