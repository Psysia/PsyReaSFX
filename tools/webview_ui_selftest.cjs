// Run with a Playwright installation path, keeping browser tooling outside the app package.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { chromium } = require(process.argv[2] || "playwright");
const root = path.resolve(
  process.argv[3] || path.join(__dirname, "../src/web"),
);
const displayVersion = JSON.parse(
  fs.readFileSync(path.join(root, "app.json"), "utf8"),
).version.replace("-beta", " Beta ");
const output = path.resolve(__dirname, "../dist/webview/verification");

async function main() {
  const server = http.createServer((request, response) => {
    const pathname = decodeURIComponent(
      new URL(request.url, "http://localhost").pathname,
    );
    const packagedAssets = path.resolve(root, "../assets");
    const base = pathname.startsWith("/assets/")
      ? fs.existsSync(packagedAssets)
        ? packagedAssets
        : path.resolve(__dirname, "../assets")
      : root;
    const file = path.resolve(
      base,
      "." +
        (pathname.startsWith("/assets/")
          ? pathname.slice(7)
          : pathname === "/"
            ? "/index.html"
            : pathname),
    );
    if (!file.startsWith(base + path.sep) || !fs.existsSync(file)) {
      response.writeHead(404).end();
      return;
    }
    response.setHeader(
      "Content-Type",
      {
        ".html": "text/html",
        ".js": "text/javascript",
        ".css": "text/css",
        ".json": "application/json",
        ".png": "image/png",
      }[path.extname(file)] || "application/octet-stream",
    );
    fs.createReadStream(file).pipe(response);
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  let browser;
  try {
    browser = await chromium.launch({
      headless: true,
      channel: process.env.PSYREASFX_BROWSER || "msedge",
    });
    const page = await browser.newPage({
      viewport: { width: 1600, height: 1000 },
      deviceScaleFactor: 1,
    });
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.addInitScript((displayVersion) => {
      let listener;
      let revision = 1;
      let count = 500000;
      let selected;
      let fx = {
        pitch: 0,
        rate: 1,
        gain_db: 0,
        loop: false,
        preserve_pitch: true,
        reverse: false,
      };
      const played = new Set();
      let playedText = true;
      let playingPath = null;
      let language = "zh";
      let aiPreset = "fixture-ai-one";
      const calls = [];
      let stateOverrides = {};
      window.testSetState = (patch) => {
        stateOverrides = { ...stateOverrides, ...patch };
        for (const key of Object.keys(patch)) {
          if (patch[key] === undefined) delete stateOverrides[key];
        }
        listener({ data: { protocol: 1, event: "state", data: state() } });
      };
      window.testEmitState = () =>
        listener({ data: { protocol: 1, event: "state", data: state() } });
      window.testPatchSelected = (patch) => {
        selected = { ...selected, ...patch };
        window.testEmitState();
      };
      window.testCalls = calls;
      const peaks = Array.from(
        { length: 128 },
        (_, index) =>
          Math.abs(Math.sin(index * 0.83) * Math.cos(index * 0.12)) *
          (0.25 + 0.75 * Math.exp(-index / 85)),
      );
      const detailPeaks = Array.from(
        { length: 1024 },
        (_, index) =>
          Math.abs(Math.sin(index * 1.37) * Math.cos(index * 0.19)) *
          (0.08 +
            0.7 * Math.exp(-Math.pow((index - 260) / 130, 2)) +
            0.2 * Math.exp(-Math.pow((index - 650) / 160, 2))),
      );
      function asset(index) {
        const names = [
          "Servo Rotation",
          "Hydraulic Release",
          "Gearbox Spin Down",
          "Robot Arm Move",
          "Heavy Actuator Stop",
          "Gear Ratchet Close",
        ];
        return {
          path: `D:\\Mechanical Motion\\${index}.wav`,
          name:
            window.testLongName ||
            `${names[(index - 1) % names.length]} ${String(index).padStart(2, "0")}.wav`,
          index,
          duration: 8.24 + (index % 4),
          channels: 2,
          sampleRate: 96000,
          bitDepth: 24,
          library: "Mechanical Motion",
          description: "机械运动，齿轮与伺服电机的自然衰减",
          keywords: "servo, gear, metal",
          category: "MECHANICAL",
          subcategory: "GEARS",
          catid: "MECHGear",
          notes: "",
          played: played.has(index),
          favorite: index % 5 === 0,
          selected: selected?.index === index,
          loudnessEnabled: true,
          loudness: [
            { label: "LUFS-I", value: "-18.4" },
            { label: "TP", value: "-1.2 dBTP" },
          ],
          waveform: {
            count: 128,
            peaks: peaks.map(
              (peak, position) =>
                peak *
                Math.abs(Math.cos(position * (0.015 + (index % 5) * 0.017))),
            ),
          },
        };
      }
      function state() {
        return {
          revision,
          language,
          count,
          loaded: 500000,
          pending: false,
          startup: null,
          status: "就绪 · 本地素材库",
          error: false,
          readOnly: false,
          libraries: [
            { id: "lib1", name: "Mechanical Motion" },
            { id: "lib2", name: "Industrial Foley" },
          ],
          roots: [
            {
              id: "r1",
              libraryId: "lib1",
              path: "D:\\Sound Effects\\Mechanical Motion",
            },
          ],
          collections: [
            { id: "c1", name: "机械场景素材箱", kind: "project", count: 7 },
          ],
          tabs: [{ id: "t1", name: "机械运动" }],
          activeTab: "t1",
          search: "",
          view: "all",
          selected,
          selectedCount: selected ? 1 : 0,
          playing: Boolean(playingPath),
          previewPath: playingPath,
          playedCount: played.size,
          rowAppearance: {
            textEnabled: playedText,
            waveformEnabled: true,
            text: "#f0c85a",
            waveform: "#d7d8da",
            played: "#8fb8d8",
            marked: "#f0c85a",
            selected: "#eaf3ff",
            selection: "#2789E9",
          },
          position: 0.24,
          regionStart: 0.12,
          regionEnd: 0.5,
          fx,
          tasks: {},
          aiHasMore: false,
          ...stateOverrides,
        };
      }
      window.chrome = {
        webview: {
          addEventListener(name, callback) {
            listener = callback;
          },
          removeEventListener() {},
          postMessage(request) {
            calls.push({ ...request, at: performance.now() });
            if (
              (request.method === "settings.get" && window.testSettingsError) ||
              (request.method === "settings.update" && window.testUpdateError)
            ) {
              queueMicrotask(() =>
                listener({
                  data: {
                    protocol: 1,
                    id: request.id,
                    ok: false,
                    error: "模拟宿主读取失败",
                  },
                }),
              );
              return;
            }
            let result = true;
            if (request.method === "artwork.url")
              result =
                "data:image/svg+xml," +
                encodeURIComponent(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" fill="#c7b57f"/><text x="12" y="64" fill="#222">Test Library</text></svg>',
                );
            if (request.method === "catalog.folders") {
              const child = request.params.path.endsWith("Child");
              result = window.testFolderPending
                ? { pending: true, items: [] }
                : {
                    pending: false,
                    total: 1,
                    items: [
                      {
                        name: child ? "Leaf" : "Child",
                        path:
                          request.params.path + (child ? "\\Leaf" : "\\Child"),
                        count: 12,
                        children: !child,
                      },
                    ],
                  };
            }
            if (request.method === "catalog.ucs")
              result = [
                {
                  name: "COMPUTERS",
                  label: "电脑",
                  entries: [
                    {
                      catid: "CMPTDriv",
                      name: "Drive",
                      label: "硬盘",
                      synonyms: "disk 磁盘",
                    },
                    { catid: "CMPTKey", name: "Keyboard", label: "键盘" },
                  ],
                },
              ];
            if (request.method === "catalog.suggestions")
              result =
                request.params.query === "mech"
                  ? [
                      {
                        catid: "MECHGear",
                        label: "MECHGear · MECHANICAL / GEAR",
                        detail: "Mechanical gears",
                        query: "catid:MECHGear",
                      },
                    ]
                  : [];
            if (request.method === "management.get")
              result = [
                {
                  kind: "library",
                  label: "音效库",
                  items: [{ id: "lib1", name: "Mechanical Motion" }],
                  actions: ["add", "rename", "scan", "remove"],
                },
                {
                  kind: "collection",
                  label: "集合",
                  items: [
                    { id: "c1", name: "机械场景素材箱", kind: "project" },
                  ],
                  actions: ["addSelection", "rename", "bind"],
                },
                {
                  kind: "search",
                  label: "保存的搜索",
                  items: [],
                  actions: ["activate", "rename"],
                },
              ];
            if (request.method === "session.ready")
              result = {
                protocol: 1,
                version: displayVersion,
                host: window.reaper ? "reaper" : "desktop",
                capabilities: { preview: true, insert: true },
                runtimePolicy: {
                  protocol: 1,
                  runtime_contracts: [2],
                  web_contracts: [1],
                  minimum_message_bytes: 900000,
                  baseline_versions: ["0.3.9.30"],
                  validation_status: "native_acceptance_pending",
                },
              };
            if (request.method === "catalog.page") {
              const offset = request.params.offset;
              result = {
                revision,
                offset,
                total: count,
                pending: false,
                items: Array.from(
                  { length: Math.min(request.params.limit, count - offset) },
                  (_, i) => asset(offset + i + 1),
                ),
              };
            }
            if (request.method === "path.choose")
              result = window.testCancelPicker
                ? { cancelled: true }
                : {
                    cancelled: false,
                    path:
                      request.params.kind === "artwork"
                        ? "D:\\封面\\cover.png"
                        : "D:\\输出目录\\Chosen",
                  };
            if (request.method === "preview.play" && selected) {
              played.add(selected.index);
              playingPath = selected.path;
            }
            if (request.method === "preview.stop") playingPath = null;
            if (request.method === "preview.toggle" && selected) {
              playingPath = playingPath ? null : selected.path;
              if (playingPath) played.add(selected.index);
            }
            if (request.method === "settings.update")
              playedText =
                request.params.values.played_text_enabled ?? playedText;
            if (request.method === "settings.update")
              language = request.params.values.language || language;
            if (
              request.method === "asset.action" &&
              request.params.action === "channelMode"
            )
              selected.channelMode = request.params.mode;
            if (request.method === "selection.set") {
              if (window.testStaleOnce) {
                window.testStaleOnce = false;
                revision++;
                result = { stale: true };
              } else {
                selected = asset(request.params.index);
                result = selected;
              }
            }
            if (request.method === "waveform.get") {
              if (request.params.retry) window.testWaveFailure = false;
              result = {
                path: request.params.path,
                duration: selected?.duration || 8.24,
                waveform: {
                  count: 1024,
                  peaks: detailPeaks,
                  channels: [detailPeaks, detailPeaks],
                },
              };
              if (window.testWaveFailure) {
                result.waveform = null;
                result.error = "波形读取失败：临时不可读";
              } else if (window.testWaveMisses > 0) {
                window.testWaveMisses--;
                result.waveform = null;
              }
            }
            if (request.method === "catalog.query") {
              count = 125;
              revision++;
            }
            if (request.method === "preview.parameters")
              fx = { ...fx, ...request.params };
            if (
              request.method === "settings.ai" &&
              request.params.action === "select"
            )
              aiPreset = request.params.id;
            if (request.method === "settings.get")
              result = {
                ai_active_preset_id: aiPreset,
                ai_presets: [
                  { id: "fixture-ai-one", name: "Preset One" },
                  { id: "fixture-ai-two", name: "Preset Two" },
                ],
                ai_preset_name:
                  aiPreset === "fixture-ai-one" ? "Preset One" : "Preset Two",
                ai_provider: "custom",
                ai_url: "https://example.invalid/v1/chat/completions",
                ai_model: "fixture-model",
                ai_key_saved: true,
                loading: Boolean(stateOverrides.startup),
                schema: [
                  {
                    key: "transfer_dir",
                    label: "输出目录",
                    kind: "string",
                    group: "Transfer",
                  },
                  {
                    key: "insert_fade_ms",
                    label: "插入淡化",
                    kind: "number",
                    group: "常规",
                    minimum: 0,
                    maximum: 100,
                  },
                  {
                    key: "waveform_hex",
                    label: "普通波形颜色",
                    kind: "color",
                    group: "试听颜色",
                  },
                  {
                    key: "multichannel_waveform",
                    label: "多声道波形",
                    kind: "boolean",
                    group: "波形与分析",
                  },
                  {
                    key: "auto_backup",
                    label: "自动备份",
                    kind: "boolean",
                    group: "维护",
                  },
                  {
                    key: "transfer_fade_in_ms",
                    label: "淡入",
                    kind: "number",
                    group: "Transfer",
                    minimum: 0,
                    maximum: 1000,
                  },
                  {
                    key: "language",
                    label: "语言",
                    kind: "choice",
                    group: "常规",
                    options: ["zh", "en"],
                  },
                  {
                    key: "played_text_enabled",
                    label: "已播放文字高亮",
                    kind: "boolean",
                    group: "试听颜色",
                  },
                ],
                values: {
                  transfer_dir: "D:\\Exports",
                  played_text_enabled: playedText,
                  language,
                  insert_fade_ms: 10,
                  waveform_hex: "#c7b57f",
                  multichannel_waveform: true,
                  auto_backup: true,
                  transfer_fade_in_ms: 5,
                },
                transfer_dir: "D:\\Exports",
                transfer_template: "{name}",
                transfer_format: "wav24",
                transfer_sample_rate: "source",
                transfer_channels: "source",
                transfer_scope: "selection",
                auto_preview: true,
              };
            const deliver = () => {
              listener({
                data: { protocol: 1, id: request.id, ok: true, result },
              });
              if (
                request.method !== "catalog.page" &&
                request.method !== "waveform.get"
              )
                listener({
                  data: { protocol: 1, event: "state", data: state() },
                });
            };
            if (request.method === "selection.set" && window.testSelectionDelay)
              setTimeout(deliver, window.testSelectionDelay);
            else queueMicrotask(deliver);
          },
        },
      };
    }, displayVersion);
    await page.addInitScript(() => {
      if (!localStorage.getItem("psyreasfx.workspace.v1"))
        localStorage.setItem(
          "psyreasfx.workspace.v1",
          JSON.stringify({
            version: 1,
            leftWidth: 245.6000213,
            rightWidth: 290.25,
            auditionHeight: 282.4,
          }),
        );
    });
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    await page.waitForSelector(".result-row");
    assert.equal(
      await page.evaluate(() =>
        document.documentElement.style.getPropertyValue("--sidebar-left"),
      ),
      "246px",
      "migrate fractional splitter widths on startup",
    );
    assert.equal(
      await page.locator("#app-version").textContent(),
      displayVersion,
    );
    assert.equal(await page.title(), `PsyReaSFX ${displayVersion}`);
    assert.equal(
      await page.locator('.column-title[data-column="index"]').count(),
      0,
      "index must be hidden by default",
    );
    assert.equal(
      await page.locator("#fx-pitch:visible").count(),
      0,
      "FX must be collapsed by default",
    );
    assert(
      (await page.locator(".result-row").count()) < 100,
      "500k catalog must render a bounded viewport",
    );
    await page.locator(".result-cell.name").first().click();
    await page.locator("#play").click();
    await page.waitForSelector(".result-row.played");
    await page.waitForSelector(".mini-playhead:not([hidden])");
    // One host anchor must yield multiple display frames without repainting
    // waveform canvases, rebuilding result rows, or requesting catalog pages.
    await page.waitForTimeout(180);
    const motion = await page.evaluate(async () => {
      window.testSetState({ position: 0.1, playing: true,
        playback: { epoch: 77, velocity: 0.1, start: 0, end: 1, loop: false } });
      const canvas = document.querySelector("#detail-wave");
      const context = canvas.getContext("2d");
      const clear = context.clearRect;
      let paints = 0;
      context.clearRect = function (...args) { paints++; return clear.apply(this, args); };
      const pagesBefore = window.testCalls.filter(c => c.method === "catalog.page").length;
      const positions = [];
      const mini = [];
      const started = performance.now();
      await new Promise(resolve => {
        function frame(now) {
          positions.push(new DOMMatrixReadOnly(document.querySelector("#detail-playhead").style.transform).m41);
          mini.push(new DOMMatrixReadOnly(document.querySelector(".mini-playhead:not([hidden])").style.transform).m41);
          if (now - started < 240) requestAnimationFrame(frame); else resolve();
        }
        requestAnimationFrame(frame);
      });
      context.clearRect = clear;
      const pagesAfter = window.testCalls.filter(c => c.method === "catalog.page").length;
      window.testSetState({ playing: false, position: 0.124 });
      const paused = document.querySelector("#detail-playhead").style.transform;
      await new Promise(resolve => setTimeout(resolve, 160));
      const held = paused === document.querySelector("#detail-playhead").style.transform;
      window.testSetState({ playing: undefined, position: undefined, playback: undefined });
      return { unique: new Set(positions).size, mini: new Set(mini).size,
        monotonic: positions.every((p,i) => !i || p >= positions[i-1]), paints, pagesBefore, pagesAfter, held };
    });
    assert(motion.unique >= 8 && motion.mini >= 8 && motion.monotonic,
      `Playheads must advance between host messages: ${JSON.stringify(motion)}`);
    assert.equal(motion.paints, 0, "cursor animation must not redraw cached waveform pixels");
    assert.equal(motion.pagesBefore, motion.pagesAfter, "cursor animation must not reload catalog data");
    assert(motion.held, "pause must freeze the visual cursor immediately");
    const resizePages = await page.evaluate(() => {
      const before = window.testCalls.filter(c => c.method === "catalog.page").length;
      for (let i=0; i<100; i++) window.dispatchEvent(new Event("resize"));
      return before;
    });
    await page.waitForTimeout(200);
    assert.equal(await page.evaluate(() => window.testCalls.filter(c => c.method === "catalog.page").length),
      resizePages, "duplicate native resize notifications must not flood catalog RPC");
    await page.locator(".result-cell.name").nth(1).click();
    assert.equal(
      await page.locator(".result-row.played:not(.selected)").count(),
      1,
    );
    await page.evaluate(() =>
      window.testSetState({
        rowAppearance: { textEnabled: false, waveformEnabled: true },
      }),
    );
    assert.equal(
      await page.locator(".result-row.played").count(),
      0,
      "appearance snapshots must redraw unchanged catalog data",
    );
    await page.evaluate(() =>
      window.testSetState({
        rowAppearance: {
          textEnabled: true,
          waveformEnabled: true,
          text: "#aabbcc",
        },
      }),
    );
    assert.equal(await page.locator(".result-row.played").count(), 1);
    assert.equal(
      await page
        .locator(".result-row.played")
        .evaluate((element) => element.style.getPropertyValue("--played-text")),
      "#aabbcc",
    );
    await page.evaluate(() =>
      window.testSetState({ rowAppearance: undefined }),
    );
    await page.locator("#settings-open").click();
    await page.waitForSelector("#settings-dialog[open]", { timeout: 3000 });
    await page.locator('[data-section="appearance"]').click();
    await page.locator('[data-setting="played_text_enabled"]').uncheck();
    await page.locator("#settings-apply").click();
    await page.waitForFunction(
      () => document.querySelectorAll(".result-row.played").length === 0,
    );
    await page.locator('[data-setting="played_text_enabled"]').check();
    await page.locator('[data-section="general"]').click();
    const originalDescription = await page
      .locator(".result-cell.description")
      .first()
      .textContent();
    await page.locator('[data-setting="language"]').selectOption("en");
    await page.locator("#settings-apply").click();
    await page.waitForFunction(() => document.documentElement.lang === "en-US");
    await page
      .getByRole("button", { name: "Close settings", exact: true })
      .waitFor();
    assert.equal(
      await page.locator(".result-cell.description").first().textContent(),
      originalDescription,
      "localization must preserve catalog text",
    );
    fs.mkdirSync(output, { recursive: true });
    await page.screenshot({ path: path.join(output, "english-settings.png") });
    await page.locator('[data-setting="language"]').selectOption("zh");
    await page.locator("#settings-apply").click();
    await page.waitForFunction(() => document.documentElement.lang === "zh-CN");
    await page.getByRole("button", { name: "关闭设置" }).click();
    // The migrated menus and settings must work as actual workflows, not just render.
    const initialPageCalls = await page.evaluate(
      () =>
        window.testCalls.filter((call) => call.method === "catalog.page")
          .length,
    );
    await page.evaluate(() => {
      for (let i = 0; i < 25; i++) window.testEmitState();
    });
    await page.waitForTimeout(150);
    const idlePageCalls = await page.evaluate(
      () =>
        window.testCalls.filter((call) => call.method === "catalog.page")
          .length,
    );
    assert.equal(
      idlePageCalls,
      initialPageCalls,
      "unchanged playback snapshots must not reload the catalog",
    );
    for (const key of ["file", "library", "edit", "view", "transfer", "help"]) {
      await page.locator(`[data-menu="${key}"]`).click();
      assert(
        (await page.locator("#popover:popover-open button").count()) > 0,
        `${key} menu must open`,
      );
      await page.keyboard.press("Escape");
    }
    await page.evaluate(() =>
      window.testSetState({ startup: { phase: "读取素材索引" } }),
    );
    await page.locator("#startup-state").waitFor();
    assert.match(
      await page.locator("#startup-state").textContent(),
      /PsyReaSFX/,
    );
    await page.screenshot({ path: path.join(output, "beta10-startup.png") });
    assert(
      await page.locator("#play").isDisabled(),
      "startup must disable asset actions",
    );
    const loadingCalls = await page.evaluate(
      () =>
        window.testCalls.filter((call) => call.method === "catalog.page")
          .length,
    );
    await page.locator("#settings-open").click();
    await page.locator('[data-section="general"]').click();
    await page.locator('[data-setting="insert_fade_ms"]').fill("18");
    assert(
      await page.locator("#settings-apply").isDisabled(),
      "settings writes must wait for startup",
    );
    assert.match(await page.locator("#dialog-status").textContent(), /加载/);
    assert.equal(
      await page.evaluate(
        () =>
          window.testCalls.filter((call) => call.method === "catalog.page")
            .length,
      ),
      loadingCalls,
      "loading must not poll the catalog",
    );
    await page.evaluate(() => window.testSetState({ startup: null }));
    await page.waitForFunction(
      () => !document.querySelector("#settings-apply").disabled,
    );
    await page.locator("#settings-discard").click();
    await page.locator("#settings-close").click();
    await page.locator("#settings-open").click();
    for (const key of [
      "general",
      "appearance",
      "waveform",
      "libraries",
      "collections",
      "transfer",
      "ai",
      "maintenance",
      "about",
    ]) {
      await page.locator(`[data-section="${key}"]`).click();
      await page.locator("#settings-body > h2").waitFor();
      assert(
        (await page.locator("#settings-body .settings-card").count()) > 0,
        `${key} settings must have content`,
      );
    }
    await page.locator('[data-section="ai"]').click();
    await page
      .locator('#settings-body input[data-field="name"]')
      .fill("Unsaved preset");
    await page.locator('[data-section="appearance"]').click();
    await page.locator('[data-section="ai"]').click();
    assert.equal(
      await page
        .locator('#settings-body input[data-field="name"]')
        .inputValue(),
      "Unsaved preset",
      "AI draft must survive navigation",
    );
    await page
      .getByRole("combobox", { name: "AI 预设", exact: true })
      .selectOption("fixture-ai-two");
    assert.equal(
      await page
        .locator('#settings-body input[data-field="name"]')
        .inputValue(),
      "Preset Two",
    );
    await page
      .getByRole("combobox", { name: "AI 预设", exact: true })
      .selectOption("fixture-ai-one");
    assert.equal(
      await page
        .locator('#settings-body input[data-field="name"]')
        .inputValue(),
      "Unsaved preset",
      "switching AI presets must retain each preset's draft",
    );
    await page
      .getByRole("combobox", { name: "服务商", exact: true })
      .selectOption("openai");
    await page
      .getByRole("button", { name: "gpt-4.1-mini", exact: true })
      .click();
    assert.equal(
      await page
        .locator('#settings-body input[data-field="model"]')
        .inputValue(),
      "gpt-4.1-mini",
    );
    await page
      .getByRole("button", { name: "删除已保存 Key", exact: true })
      .click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "settings.ai" &&
          call.params.action === "deleteKey" &&
          call.params.id === "fixture-ai-one",
      ),
    );
    assert.equal(
      await page
        .locator('#settings-body input[data-field="name"]')
        .inputValue(),
      "Unsaved preset",
      "deleting a saved key must not discard other draft fields",
    );
    await page.locator("#settings-close").click();
    assert(
      await page
        .locator("#settings-dialog")
        .evaluate((element) => element.open),
      "closing must preserve an unsaved AI preset",
    );
    await page.locator("#settings-discard").click();
    await page.locator('[data-section="general"]').click();
    const updatesBefore = await page.evaluate(
      () =>
        window.testCalls.filter((call) => call.method === "settings.update")
          .length,
    );
    await page.locator('[data-setting="insert_fade_ms"]').fill("25");
    await page.locator('[data-setting="insert_fade_ms"]').press("Enter");
    assert(
      await page
        .locator("#settings-dialog")
        .evaluate((element) => element.open),
      "Enter in a setting must not close the panel",
    );
    await page.locator('[data-section="appearance"]').click();
    await page.locator('[data-section="general"]').click();
    assert.equal(
      await page.locator('[data-setting="insert_fade_ms"]').inputValue(),
      "25",
      "draft must survive category navigation",
    );
    assert.equal(
      await page.evaluate(
        () =>
          window.testCalls.filter((call) => call.method === "settings.update")
            .length,
      ),
      updatesBefore,
      "settings are staged until Apply",
    );
    await page.evaluate(() => {
      window.testUpdateError = true;
    });
    await page.locator("#settings-apply").click();
    await page.locator("#dialog-status.error").waitFor();
    assert.equal(
      await page.locator('[data-setting="insert_fade_ms"]').inputValue(),
      "25",
      "a failed save must retain the draft",
    );
    await page.evaluate(() => {
      window.testUpdateError = false;
    });
    await page.locator("#settings-apply").click();
    await page.waitForFunction(
      () => document.querySelector("#settings-apply").disabled,
    );
    await page.locator("#settings-search").fill("波形");
    await page.locator('[data-setting="waveform_hex"]').waitFor();
    await page.locator("#settings-search").fill("");
    await page.locator('[data-section="appearance"]').click();
    await page.screenshot({ path: path.join(output, "settings-rewrite.png") });
    await page.locator("#settings-close").click();
    await page.locator('[data-menu="library"]').click();
    await page
      .getByRole("button", { name: "新建播放列表", exact: true })
      .click();
    await page.locator("#input-value").fill("My playlist");
    await page.locator("#input-value").press("Enter");
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "collection.create" &&
          call.params.kind === "playlist" &&
          call.params.name === "My playlist",
      ),
    );
    await page.evaluate(() =>
      window.testSetState({ regionStart: 0.2, regionEnd: 0.6 }),
    );
    const dragBox = await page.locator("#drag-selection").boundingBox();
    await page.mouse.move(dragBox.x + 12, dragBox.y + 12);
    await page.mouse.down();
    await page.mouse.move(dragBox.x + 30, dragBox.y + 12);
    await page.waitForFunction(() =>
      window.testCalls.some((call) => call.method === "drag.begin"),
    );
    const dragBegin = await page.evaluate(() =>
      window.testCalls.filter((call) => call.method === "drag.begin").at(-1),
    );
    assert.equal(dragBegin.params.selection, true);
    assert.equal(dragBegin.params.start, 0.2);
    assert.equal(dragBegin.params.finish, 0.6);
    assert(
      await page.locator("#drag-hint").isVisible(),
      "start native handoff before mouse-up",
    );
    await page.keyboard.press("Escape");
    await page.mouse.up();
    await page.waitForFunction(() =>
      window.testCalls.some((call) => call.method === "drag.cancel"),
    );
    assert(!(await page.locator("#drag-hint").isVisible()));
    await page.evaluate(() =>
      window.testSetState({ regionStart: undefined, regionEnd: undefined }),
    );
    await page.locator("#save-region").click();
    await page.locator("#input-value").fill("Metal tail");
    await page.locator("#input-value").press("Enter");
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "region.action" && call.params.name === "Metal tail",
      ),
    );
    await page.locator("#transfer-open").click();
    await page
      .locator('[data-field="transfer_template"]')
      .fill("{name}_edited");
    await page.evaluate(() => window.testEmitState());
    assert.equal(
      await page.locator('[data-field="transfer_template"]').inputValue(),
      "{name}_edited",
      "playback snapshots must not destroy Transfer input",
    );
    await page.locator('[data-inspector="metadata"]').click();
    await page.locator('[data-inspector="transfer"]').click();
    assert.equal(
      await page.locator('[data-field="transfer_template"]').inputValue(),
      "{name}_edited",
      "Transfer draft must survive inspector tabs",
    );
    await page.locator('[data-inspector="metadata"]').click();
    await page.evaluate(() =>
      window.testSetState({ tasks: { transfer: true, scan: true } }),
    );
    assert.match(
      await page.locator("#activity-text").textContent(),
      /交付.*扫描|扫描.*交付/,
    );
    await page.locator("#activity-status").click();
    await page.waitForSelector("#task-panel:popover-open");
    await page.locator("#activity-status").click();
    await page.waitForFunction(
      () => !document.querySelector("#task-panel").matches(":popover-open"),
    );
    await page.mouse.move(800, 50);
    await page.locator("#activity-status").hover();
    await page.waitForSelector("#task-panel:popover-open");
    await page.locator("#task-panel").hover();
    await page.waitForTimeout(280);
    assert(
      await page.locator("#task-panel").isVisible(),
      "hover details must stay open while entering them",
    );
    await page
      .getByRole("button", { name: "停止 · 扫描", exact: true })
      .click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) => call.method === "tasks.cancel" && call.params.task === "scan",
      ),
    );
    await page.evaluate(() => window.testSetState({ tasks: {} }));
    await page.locator("#search").fill("mech");
    await page.waitForSelector(
      '#search-suggestions:popover-open [role="option"]',
    );
    await page.locator("#search").press("ArrowDown");
    await page.locator("#search").press("Enter");
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "catalog.query" &&
          call.params.search === "catid:MECHGear" &&
          call.params.keepScope === true,
      ),
    );
    assert.equal(
      await page.locator("#search").getAttribute("aria-expanded"),
      "false",
    );
    await page.locator(".result-cell.name").nth(1).click();
    await page
      .locator("#inspector-body summary")
      .filter({ hasText: "试听声道" })
      .click();
    await page.getByRole("button", { name: "左声道", exact: true }).click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "asset.action" &&
          call.params.action === "channelMode" &&
          call.params.mode === "left",
      ),
    );
    await page.evaluate(() => {
      window.testSettingsError = true;
    });
    await page.locator("#settings-open").click();
    await page.getByRole("button", { name: "重新读取设置" }).waitFor();
    await page.evaluate(() => {
      window.testSettingsError = false;
    });
    await page.getByRole("button", { name: "重新读取设置" }).click();
    await page.locator('[data-section="ai"]').click();
    await page.locator('#settings-body input[type="password"]').waitFor();
    await page.getByRole("button", { name: "关闭设置" }).click();
    const before = await page.locator("#detail-wave").boundingBox();
    await page.locator("#left-toggle").click();
    await page.locator("#right-toggle").click();
    const after = await page.locator("#detail-wave").boundingBox();
    assert.equal(
      after.x,
      before.x,
      "sidebars must not move the full-width waveform",
    );
    assert.equal(
      after.width,
      before.width,
      "sidebars must not shrink the full-width waveform",
    );
    await page.locator("#right-toggle").click();
    await page.locator('.result-cell[data-column="name"]').first().click();
    const splitter = await page.locator('[data-resize="left"]').boundingBox();
    await page.mouse.move(splitter.x + 2, splitter.y + 60);
    await page.mouse.down();
    await page.mouse.move(splitter.x + 42, splitter.y + 60);
    await page.mouse.up();
    const resized = await page.locator("#detail-wave").boundingBox();
    assert.equal(
      resized.width,
      before.width,
      "sidebar resize must keep waveform width",
    );
    assert.equal(
      resized.x,
      before.x,
      "sidebar resize must keep waveform horizontal origin",
    );
    await page.waitForSelector("#inspector-body textarea");
    const closedWaveHeight = (await page.locator("#detail-wave").boundingBox())
      .height;
    const closedPlayerHeight = (await page.locator("#audition").boundingBox())
      .height;
    await page.locator("#fx-toggle").click();
    await page.waitForSelector("#fx-pitch:visible");
    assert(
      Math.abs(
        (await page.locator("#detail-wave").boundingBox()).height -
          closedWaveHeight,
      ) < 2,
      "opening FX must not enlarge or shrink the waveform",
    );
    assert.equal(
      (await page.locator("#audition").boundingBox()).height -
        closedPlayerHeight,
      48,
      "opening FX adds only the compact toolbar",
    );
    const fxWidth = await page.locator("#detail-wave").boundingBox();
    assert.equal(
      fxWidth.width,
      before.width,
      "expanded FX must keep waveform width",
    );
    await page.locator("#fx-toggle").click();
    await page.locator("#column-head").click({ button: "right" });
    await page
      .locator("#popover label")
      .filter({ hasText: "预览波形" })
      .locator("input")
      .uncheck();
    assert.equal(
      await page.locator(".result-cell.waveform").count(),
      0,
      "waveform column must be optional",
    );
    await page
      .locator("#popover label")
      .filter({ hasText: "预览波形" })
      .locator("input")
      .check();
    await page
      .locator("#popover label")
      .filter({ hasText: "序号" })
      .locator("input")
      .check();
    assert.equal(
      await page.locator('.column-title[data-column="index"]').count(),
      1,
    );
    await page
      .locator("#popover label")
      .filter({ hasText: "序号" })
      .locator("input")
      .uncheck();
    await page.keyboard.press("Escape");
    await page.locator("#search").fill("metal impact");
    await page.locator("#search").press("Enter");
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "catalog.query" &&
          call.params.search === "metal impact",
      ),
    );
    assert.equal(
      new URL(page.url()).pathname,
      "/",
      "search must not navigate away",
    );
    await page.locator("#result-scroll").evaluate((element) => {
      element.scrollTop = 1500;
    });
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) => call.method === "catalog.page" && call.params.offset > 20,
      ),
    );
    assert((await page.locator(".result-row").count()) < 100);
    await page.locator("#result-scroll").evaluate((element) => {
      element.scrollTop = 0;
    });
    await page.waitForTimeout(100);
    fs.mkdirSync(output, { recursive: true });
    await page.screenshot({ path: path.join(output, "expanded-sidebars.png") });
    await page.locator("#left-toggle").click();
    await page.screenshot({ path: path.join(output, "default-dark.png") });
    await page.locator("#settings-open").click();
    await page.locator('[data-section="appearance"]').click();
    assert(
      Number.isInteger(
        Number(
          await page.locator('[data-preference="leftWidth"]').inputValue(),
        ),
      ),
      "dragged splitter widths must remain valid integers",
    );
    assert(
      await page
        .locator('[data-preference="auditionHeight"]')
        .evaluate((input) => input.validity.valid),
    );
    await page.locator('[data-preference="theme"]').selectOption("everforest");
    await page.locator('[data-preference="themeMode"]').selectOption("light");
    await page.locator("#settings-apply").click();
    await page.locator("#settings-close").click();
    await page.reload();
    await page.waitForSelector(".result-row");
    assert.equal(
      await page.locator("body").getAttribute("data-theme"),
      "everforest",
      "theme choice must persist",
    );
    await page.screenshot({ path: path.join(output, "optional-paper.png") });
    const variants = await page.evaluate(
      async () => (await import("./themes.js")).themeVariants,
    );
    assert.equal(variants.length, 44);
    assert.equal(new Set(variants.map((item) => item.id)).size, 29);
    assert.deepEqual(
      variants.find((item) => item.id === "github" && item.tone === "dark"),
      {
        id: "github",
        label: "GitHub",
        tone: "dark",
        background: "#0d1117",
        foreground: "#e6edf3",
        accent: "#1f6feb",
      },
    );
    for (const variant of variants) {
      const theme = variant.id;
      await page.locator("#settings-open").click();
      await page.locator('[data-section="appearance"]').click();
      assert.equal(await page.locator(".theme-preset").count(), 29);
      await page.locator(`[data-theme-preset="${theme}"]`).click();
      await page
        .locator('[data-preference="themeMode"]')
        .selectOption(variant.tone);
      const presetAccent = await page
        .locator('[data-preference="accentColor"]')
        .inputValue();
      await page.locator("#settings-apply").click();
      await page.locator("#settings-close").click();
      assert.equal(
        await page.locator("body").getAttribute("data-theme"),
        theme,
      );
      const colors = await page.locator("body").evaluate((body) => ({
        accent: getComputedStyle(body).getPropertyValue("--accent").trim(),
        background: getComputedStyle(body).getPropertyValue("--bg").trim(),
        foreground: getComputedStyle(body).getPropertyValue("--text").trim(),
        search: getComputedStyle(body).getPropertyValue("--search-bg").trim(),
        expectedSearch: getComputedStyle(body)
          .getPropertyValue("--input")
          .trim(),
        list: getComputedStyle(document.getElementById("result-scroll"))
          .backgroundColor,
        player: getComputedStyle(document.getElementById("audition"))
          .backgroundColor,
        input: getComputedStyle(document.querySelector("#fx-gain-value"))
          .backgroundColor,
      }));
      assert.equal(
        colors.search,
        colors.expectedSearch,
        "search surface must follow the active palette, including light themes",
      );
      assert.equal(
        colors.list,
        colors.player,
        "list and large waveform must share the workspace surface",
      );
      assert.notEqual(
        colors.accent,
        "#c7b57f",
        "preset accents must not be masked by legacy defaults",
      );
      assert.equal(
        colors.accent,
        presetAccent,
        "the editable accent must match the preset",
      );
      assert.equal(colors.background, variant.background);
      assert.equal(colors.foreground, variant.foreground);
      assert.equal(colors.accent, variant.accent);
      if (["github", "codex", "catppuccin"].includes(theme))
        await page.screenshot({
          path: path.join(output, `beta13-theme-${theme}-${variant.tone}.png`),
        });
    }
    await page.emulateMedia({ colorScheme: "dark" });
    await page.locator("#settings-open").click();
    await page.locator('[data-section="appearance"]').click();
    await page.locator('[data-preference="theme"]').selectOption("github");
    await page.locator('[data-preference="themeMode"]').selectOption("system");
    await page.locator("#settings-apply").click();
    await page.locator("#settings-close").click();
    await page.emulateMedia({ colorScheme: "light" });
    await page.waitForFunction(() => document.body.dataset.tone === "light");
    await page.reload();
    await page.waitForSelector(".result-row");
    await page.emulateMedia({ colorScheme: "dark" });
    await page.waitForFunction(() => document.body.dataset.tone === "dark");
    assert.equal(
      await page
        .locator("body")
        .evaluate((body) =>
          getComputedStyle(body).getPropertyValue("--bg").trim(),
        ),
      "#0d1117",
    );
    await page.locator("#settings-open").click();
    await page.locator('[data-section="appearance"]').click();
    await page.locator('[data-preference="accentColor"]').fill("#c7b57f");
    await page.locator("#settings-apply").click();
    assert.equal(
      await page
        .locator("body")
        .evaluate((body) =>
          getComputedStyle(body).getPropertyValue("--accent").trim(),
        ),
      "#c7b57f",
      "custom gold must work on non-dark presets too",
    );
    await page.locator("#settings-close").click();
    await page.locator("#settings-open").click();
    await page.locator('[data-section="transfer"]').click();
    await page
      .getByRole("button", { name: "浏览输出目录", exact: true })
      .click();
    assert.equal(
      await page.locator('[data-setting="transfer_dir"]').inputValue(),
      "D:\\输出目录\\Chosen",
    );
    await page.evaluate(() => {
      window.testCancelPicker = true;
    });
    await page
      .getByRole("button", { name: "浏览输出目录", exact: true })
      .click();
    assert.equal(
      await page.locator('[data-setting="transfer_dir"]').inputValue(),
      "D:\\输出目录\\Chosen",
      "cancel must preserve the path draft",
    );
    await page.locator("#settings-discard").click();
    await page.locator('[data-section="about"]').click();
    await page.waitForFunction(
      () => document.querySelector(".about-logo")?.naturalWidth > 0,
    );
    await page.screenshot({ path: path.join(output, "beta12-about.png") });
    await page
      .getByRole("button", { name: "GitHub 项目主页", exact: true })
      .click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (c) => c.method === "app.link" && c.params.target === "project",
      ),
    );
    await page.locator("#settings-close").click();
    await page.setViewportSize({ width: 1000, height: 720 });
    await page.screenshot({ path: path.join(output, "compact-window.png") });
    // Capture seek coordinates before selection replaces the virtualized row.
    for (const fraction of [0.15, 0.55, 0.85]) {
      const canvas = page.locator(".result-cell.waveform canvas").nth(2);
      const box = await canvas.boundingBox();
      const before = await page.evaluate(
        () =>
          window.testCalls.filter((c) => c.method === "preview.play").length,
      );
      await page.mouse.click(
        box.x + box.width * fraction,
        box.y + box.height / 2,
      );
      await page.waitForFunction(
        (n) =>
          window.testCalls.filter((c) => c.method === "preview.play").length >
          n,
        before,
      );
      const call = await page.evaluate(() =>
        window.testCalls.filter((c) => c.method === "preview.play").at(-1),
      );
      assert(
        Math.abs(call.params.position - fraction) < 0.01,
        "mini waveform must seek to the actual canvas position after row refresh",
      );
      assert.equal(call.params.selection, false);
    }
    const doubleBox = await page
      .locator(".result-cell.waveform canvas")
      .nth(2)
      .boundingBox();
    const doubleBefore = await page.evaluate(
      () => window.testCalls.filter((c) => c.method === "preview.play").length,
    );
    await page.mouse.dblclick(
      doubleBox.x + doubleBox.width * 0.6,
      doubleBox.y + doubleBox.height / 2,
    );
    await page.waitForFunction(
      (n) =>
        window.testCalls.filter((c) => c.method === "preview.play").length > n,
      doubleBefore,
    );
    await page.waitForTimeout(80);
    const doubles = await page.evaluate(
      (n) =>
        window.testCalls.filter((c) => c.method === "preview.play").slice(n),
      doubleBefore,
    );
    assert(
      doubles.every((c) => Math.abs(c.params.position - 0.6) < 0.01),
      "double click must not bubble into restart-from-zero",
    );
    await page.evaluate(() => {
      window.testSelectionDelay = 180;
    });
    const delayedBefore = await page.evaluate(
      () => window.testCalls.filter((c) => c.method === "preview.play").length,
    );
    await page.locator(".result-cell.waveform").nth(1).click();
    await page.locator("#stop").click();
    await page.waitForTimeout(240);
    assert.equal(
      await page.evaluate(
        () =>
          window.testCalls.filter((c) => c.method === "preview.play").length,
      ),
      delayedBefore,
      "stop must cancel a pending thumbnail audition",
    );
    await page.evaluate(() => {
      window.testSelectionDelay = 0;
    });
    const modifierBefore = await page.evaluate(
      () => window.testCalls.filter((c) => c.method === "preview.play").length,
    );
    await page
      .locator(".result-cell.waveform")
      .nth(3)
      .click({ modifiers: ["Control"] });
    await page
      .locator(".result-cell.waveform")
      .nth(4)
      .click({ modifiers: ["Shift"] });
    assert.equal(
      await page.evaluate(
        () =>
          window.testCalls.filter((c) => c.method === "preview.play").length,
      ),
      modifierBefore,
      "modifier clicks retain range/toggle selection",
    );
    // Beta 9: local audition keys, compact translated menus and submenu navigation.
    await page.locator(".result-cell.name").first().click();
    await page.locator("#stop").click();
    const toggles = await page.evaluate(
      () =>
        window.testCalls.filter((c) => c.method === "preview.toggle").length,
    );
    assert.equal(
      await page.evaluate(
        () =>
          JSON.parse(localStorage.getItem("psyreasfx.workspace.v1") || "{}")
            .previewBehavior || "pause",
      ),
      "pause",
    );
    await page.locator("#play").focus();
    await page.keyboard.down("Space");
    await page.keyboard.down("Space");
    await page.keyboard.up("Space");
    await page.waitForFunction(
      (n) =>
        window.testCalls.filter((c) => c.method === "preview.toggle").length ===
        n + 1,
      toggles,
    );
    await page.keyboard.press("Space");
    await page.waitForFunction(
      (n) =>
        window.testCalls.filter((c) => c.method === "preview.toggle").length ===
        n + 2,
      toggles,
    );
    await page.locator("#search").fill("edit");
    await page.keyboard.press("Space");
    assert.equal(await page.locator("#search").inputValue(), "edit ");
    assert.equal(
      await page.evaluate(
        () =>
          window.testCalls.filter((c) => c.method === "preview.toggle").length,
      ),
      toggles + 2,
      "text entry must not control audition",
    );
    assert.equal(
      await page.evaluate(
        () =>
          window.testCalls.filter((c) => c.method === "preview.toggle").at(-1)
            .params.behavior,
      ),
      "pause",
    );
    await page.locator("#settings-open").click();
    await page.locator('[data-section="general"]').click();
    await page
      .locator('[data-preference="previewBehavior"]')
      .selectOption("stop");
    await page.locator("#settings-apply").click();
    await page.locator("#settings-close").click();
    await page.locator("#play").click();
    await page.waitForFunction(
      () =>
        window.testCalls.filter((c) => c.method === "preview.toggle").at(-1)
          .params.behavior === "stop",
    );
    await page.locator("#settings-open").click();
    await page.locator('[data-section="general"]').click();
    await page
      .locator('[data-preference="previewBehavior"]')
      .selectOption("pause");
    await page.locator("#settings-apply").click();
    await page.locator("#settings-close").click();
    await page.locator("#search").fill("");
    await page.evaluate(() => {
      window.testLongName =
        "AEROHeli_" + "Helicopter Maneuvers Approach ".repeat(12) + ".wav";
      window.testSetState({ revision: 9001 });
    });
    await page.waitForFunction(() =>
      document
        .querySelector(".result-cell.name")
        .textContent.includes("AEROHeli_"),
    );
    await page.locator(".result-cell.name").first().click({ button: "right" });
    const zhMenu = await page.locator("#popover").boundingBox();
    assert(
      zhMenu.width < 280,
      "a long filename must not stretch the Chinese menu",
    );
    assert(
      (await page.locator("#popover .menu-item").count()) < 15,
      "secondary actions belong to groups",
    );
    await page.screenshot({ path: path.join(output, "beta10-menu-zh.png") });
    await page
      .locator("#popover")
      .getByRole("button", { name: "插入 REAPER", exact: false })
      .focus();
    await page.keyboard.press("ArrowRight");
    await page
      .getByRole("button", { name: "插入新轨道", exact: true })
      .waitFor();
    await page.keyboard.press("ArrowLeft");
    assert.equal(
      await page.locator('.menu-panel[data-menu-level="1"]').count(),
      0,
    );
    await page
      .locator("#popover")
      .getByRole("button", { name: "分析与元数据", exact: false })
      .hover();
    await page.locator('.menu-panel[data-menu-level="1"]').waitFor();
    assert(
      await page
        .locator("#popover")
        .getByRole("button", { name: "分析与元数据", exact: false })
        .isVisible(),
      "hover must retain the parent menu",
    );
    await page.locator('.menu-panel[data-menu-level="1"]').hover();
    assert.equal(
      await page.locator(".menu-panel").count(),
      2,
      "moving into a submenu must keep it open",
    );
    await page.screenshot({ path: path.join(output, "beta10-hover-menu.png") });
    const submenuBox = await page
      .locator('.menu-panel[data-menu-level="1"]')
      .boundingBox();
    assert(
      submenuBox.x >= 0 &&
        submenuBox.x + submenuBox.width <= page.viewportSize().width &&
        submenuBox.y >= 0 &&
        submenuBox.y + submenuBox.height <= page.viewportSize().height,
      "submenu must remain inside viewport",
    );
    assert(
      await page
        .getByRole("button", { name: "分析与元数据", exact: false })
        .isVisible(),
    );
    await page.keyboard.press("Escape");
    await page
      .locator(".result-row")
      .first()
      .evaluate((row) =>
        row.dispatchEvent(
          new MouseEvent("contextmenu", {
            clientX: 990,
            clientY: 690,
            bubbles: true,
            cancelable: true,
          }),
        ),
      );
    await page
      .getByRole("button", { name: "分析与元数据", exact: false })
      .hover();
    await page.locator('.menu-panel[data-menu-level="1"]').waitFor();
    const edgeSubmenu = await page
      .locator('.menu-panel[data-menu-level="1"]')
      .boundingBox();
    const edgeParent = await page.locator("#popover").boundingBox();
    await page.screenshot({ path: path.join(output, "beta10-edge-menu.png") });
    assert(
      edgeSubmenu.x >= 0 &&
        edgeSubmenu.x + edgeSubmenu.width <= edgeParent.x + 1 &&
        edgeSubmenu.y + edgeSubmenu.height <= page.viewportSize().height,
      `near the right/bottom edge, the submenu must flip left and remain visible: ${JSON.stringify({ edgeSubmenu, edgeParent, viewport: page.viewportSize() })}`,
    );
    await page.keyboard.press("Escape");
    await page.evaluate(() => window.testSetState({ language: "en" }));
    await page.locator(".result-cell.name").first().click({ button: "right" });
    await page
      .getByRole("button", { name: "Analysis and metadata", exact: false })
      .waitFor();
    const enMenu = await page.locator("#popover").boundingBox();
    assert(
      enMenu.width > zhMenu.width && enMenu.width < 340,
      "menu width adapts to translated commands",
    );
    await page.screenshot({ path: path.join(output, "beta10-menu-en.png") });
    await page.keyboard.press("Escape");
    await page.evaluate(() => {
      window.testLongName = undefined;
      window.testSetState({ language: undefined, revision: undefined });
    });
    // Real reported failures: nested navigation, late cache results, scrolling
    // artwork, stale row identity, loudness visibility and constrained FX layout.
    await page.setViewportSize({ width: 1600, height: 1000 });
    await page.reload();
    await page.waitForSelector(".result-row");
    await page.locator("#settings-open").click();
    await page.locator('[data-section="appearance"]').click();
    await page.locator('[data-preference="theme"]').selectOption("github");
    await page.locator('[data-preference="themeMode"]').selectOption("dark");
    await page.locator('[data-preference="left"]').check();
    await page.locator('[data-preference="right"]').check();
    await page.locator('[data-preference="fx"]').uncheck();
    await page.locator('[data-preference="fontSize"]').fill("13");
    await page.locator('[data-preference="leftWidth"]').fill("206");
    await page.locator('[data-preference="auditionHeight"]').fill("282");
    await page.locator("#settings-apply").click();
    await page.locator("#settings-close").click();
    assert.equal(
      await page.locator("body").getAttribute("data-theme"),
      "github",
    );
    assert.equal(
      await page.locator('[data-rail="settings"]').count(),
      0,
      "settings must have one toolbar entry",
    );
    await page.locator('[data-rail="libraries"]').click();
    assert(await page.locator("#libraries").isVisible());
    assert(!(await page.locator("#views").isVisible()));
    assert.equal(
      await page.locator("#collection-menu").count(),
      0,
      "remove the redundant top collection entry",
    );
    assert(await page.locator("#activity-status").isVisible());
    assert.equal(await page.locator("#tasks-menu, #host-label").count(), 0);
    const libraryIcon = await page
      .locator(".library-row .ui-icon")
      .first()
      .boundingBox();
    const libraryName = await page
      .locator(".library-row .nav-item > span")
      .first()
      .boundingBox();
    assert(
      libraryName.x - libraryIcon.x < 45,
      "library icon must not push the name to the right edge",
    );
    const navFont = await page
      .locator("#libraries > .library-branch > .library-row > .nav-item")
      .first()
      .evaluate((el) => getComputedStyle(el).fontSize);
    await page.evaluate(() => {
      window.testFolderPending = true;
    });
    await page
      .locator(
        "#libraries > .library-branch > .folder-branch > summary > .folder-toggle",
      )
      .click();
    await page
      .locator("#libraries .folder-state")
      .filter({ hasText: "正在整理文件夹索引" })
      .waitFor();
    await page.evaluate(() => {
      window.testFolderPending = false;
    });
    await page.locator("#libraries .folder-branch .folder-branch").waitFor();
    await page
      .locator(
        "#libraries .folder-branch .folder-branch > summary > .folder-toggle",
      )
      .click();
    await page
      .locator("#libraries .folder-row .nav-item")
      .filter({ hasText: "Leaf" })
      .waitFor();
    const rootLabel = page.locator(
      "#libraries > .library-branch > .folder-branch > summary > .nav-item",
    );
    await rootLabel.dblclick({ delay: 100 });
    await page.waitForFunction(
      () =>
        !document.querySelector("#libraries > .library-branch > .folder-branch")
          .open,
    );
    await rootLabel.dblclick({ delay: 100 });
    await page.waitForFunction(
      () =>
        document.querySelector("#libraries > .library-branch > .folder-branch")
          .open,
    );
    const rootArrow = page.locator(
      "#libraries > .library-branch > .folder-branch > summary > .folder-toggle",
    );
    const labelBox = await rootLabel.boundingBox(),
      arrowBox = await rootArrow.boundingBox();
    assert(
      Math.abs(
        labelBox.y + labelBox.height / 2 - arrowBox.y - arrowBox.height / 2,
      ) < 2,
      `folder disclosure and name must share one row: ${JSON.stringify({ labelBox, arrowBox })}`,
    );
    await page
      .locator("#libraries .folder-row .nav-item")
      .filter({ hasText: "Leaf" })
      .click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "catalog.query" &&
          call.params.root?.endsWith("\\Child\\Leaf"),
      ),
    );
    await page.screenshot({
      path: path.join(output, "beta10-library-tree.png"),
    });
    await page.locator('[data-rail="ucs"]').click();
    assert(!(await page.locator("#libraries").isVisible()));
    await page.locator("#ucs-categories > details > summary").click();
    const ucsItem = page
      .locator("#ucs-categories .nav-item")
      .filter({ hasText: "CMPTDriv" });
    assert.equal(
      await ucsItem.evaluate((el) => getComputedStyle(el).fontSize),
      navFont,
      "expanded UCS typography must match ordinary navigation",
    );
    for (const term of ["硬盘", "drive", "cmptdriv", "磁盘", "computer disk"]) {
      await page.locator("#ucs-search").fill(term);
      assert.equal(
        await page.locator("#ucs-categories .root").count(),
        1,
        `UCS search: ${term}`,
      );
      assert(
        await ucsItem.isVisible(),
        "search results expand without requiring another click",
      );
    }
    await page.locator("#ucs-search").fill("no_such_category");
    assert.equal(await page.locator("#ucs-categories .nav-item").count(), 0);
    assert.match(
      await page.locator("#ucs-search-status").textContent(),
      /没有匹配/,
    );
    await page.locator("#ucs-search-clear").click();
    assert(
      await ucsItem.isVisible(),
      "clearing search restores the previously expanded group",
    );
    assert.equal(await page.locator("#ucs-categories .root").count(), 2);
    await ucsItem.click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "catalog.query" && call.params.catid === "CMPTDriv",
      ),
    );
    await page.locator('[data-rail="collections"]').click();
    assert(await page.locator("#collections").isVisible());
    assert(!(await page.locator("#ucs-directory").isVisible()));
    await page.locator('[data-rail="all"]').click();
    await page.evaluate(() => {
      window.testStaleOnce = true;
    });
    await page.locator(".result-cell.name").first().click();
    await page.waitForFunction(
      () =>
        window.testCalls.filter((call) => call.method === "selection.set")
          .length >= 2,
    );
    assert.equal(
      await page.locator("#toast:not([hidden])").count(),
      0,
      "stale selection should refresh and retry without a false error",
    );
    await page
      .locator("#loudness-strip")
      .filter({ hasText: "LUFS-I" })
      .waitFor();
    assert.match(
      await page.locator("#loudness-strip").textContent(),
      /-18.4.*-1.2 dBTP/,
    );
    await page.evaluate(() =>
      window.testPatchSelected({ artwork_path: "fixture-cover.png" }),
    );
    await page.locator(".artwork-cover:not([hidden])").waitFor();
    const coverTop = (await page.locator(".artwork-cover").boundingBox()).y;
    const tabsTop = (await page.locator(".inspector-tabs").boundingBox()).y;
    await page.locator("#inspector-body").evaluate((el) => {
      el.scrollTop = 450;
    });
    assert(
      (await page.locator(".artwork-cover").boundingBox()).y < coverTop - 200,
      "cover must scroll with metadata, not hover over fields",
    );
    assert.equal(
      (await page.locator(".inspector-tabs").boundingBox()).y,
      tabsTop,
    );
    await page.evaluate(() => {
      window.testWaveFailure = true;
    });
    await page.locator(".result-cell.name").nth(1).click();
    await page.locator("#wave-retry:not([hidden])").waitFor();
    await page.locator("#wave-retry").click();
    await page.waitForFunction(
      () => document.getElementById("wave-status").hidden,
    );
    await page.evaluate(() => {
      window.testWaveMisses = 2;
      window.testWaveStart = performance.now();
    });
    await page.locator(".result-cell.name").nth(2).click();
    await page.waitForFunction(
      () =>
        window.testWaveMisses === 0 &&
        document.getElementById("wave-status").hidden,
    );
    const retryLatency = await page.evaluate(
      () => performance.now() - window.testWaveStart,
    );
    assert(
      retryLatency < 700,
      `cached waveform polling must not add an 850ms delay: ${retryLatency}`,
    );
    await page.evaluate(() =>
      window.testSetState({ regionStart: 0, regionEnd: 1 }),
    );
    const backgroundPixel = await page
      .locator("#detail-wave")
      .evaluate((canvas) =>
        Array.from(canvas.getContext("2d").getImageData(95, 34, 1, 1).data),
      );
    assert.equal(
      backgroundPixel[3],
      0,
      "full-file range must not inherit the legacy blue fill",
    );
    await page.locator("#similar-search").click();
    await page
      .getByRole("button", { name: "在当前结果内查找相似声音", exact: true })
      .click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "search.similar" && call.params.scope === "current",
      ),
    );
    await page.evaluate(() =>
      window.testSetState({
        tasks: { similar: true },
        similarityProgress: {
          phase: "building-cache",
          completed: 27,
          total: 125,
          reference: "fixture.wav",
        },
      }),
    );
    await page.locator("#activity-status").click();
    assert.match(
      await page.locator("#analysis-bar").textContent(),
      /建立声音特征缓存.*27 \/ 125/s,
    );
    await page.locator("#analysis-cancel").click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "tasks.cancel" && call.params.task === "similar",
      ),
    );
    await page.evaluate(() =>
      window.testSetState({
        tasks: { scan: true, similar: true },
        taskDetails: {
          scan: {
            files: 85179,
            directories: 200,
            path: "D:\\音效库\\机械",
            label: "更新来源",
            total: 0,
            completed: 0,
          },
        },
        similarityProgress: {
          phase: "waiting",
          completed: 0,
          total: 0,
          reference: "fixture.wav",
          waitingFor: "扫描",
        },
      }),
    );
    await page.waitForFunction(() =>
      document
        .getElementById("analysis-label")
        .textContent.includes("等待扫描完成"),
    );
    assert.equal(
      await page.locator("#analysis-cancel").textContent(),
      "取消等待",
    );
    assert.equal(await page.locator("#task-count").textContent(), "2");
    assert.match(
      await page.locator("#task-list").textContent(),
      /85,179.*200.*D:\\音效库\\机械/s,
    );
    await page.screenshot({
      path: path.join(output, "beta11-task-details.png"),
    });
    await page.locator("#analysis-cancel").click();
    await page.waitForFunction(
      () =>
        window.testCalls.filter((call) => call.method === "tasks.cancel").at(-1)
          .params.task === "similar",
    );
    await page.locator("#tasks-close").click();
    assert.equal(await page.locator("#app > footer").count(), 0);
    assert.equal(await page.locator("#wave-readouts").count(), 0);
    await page.locator("#fx-toggle").click();
    for (const size of [
      { width: 1600, height: 1000 },
      { width: 1000, height: 720 },
      { width: 900, height: 620 },
    ]) {
      await page.setViewportSize(size);
      await page.waitForTimeout(80);
      const boxes = await page.evaluate(() =>
        Object.fromEntries(
          [
            "detail-wave",
            "asset-info",
            "fx-panel",
            "audition",
            "loudness-strip",
          ]
            .map((id) => {
              const r = document.getElementById(id).getBoundingClientRect();
              return [id, { top: r.top, bottom: r.bottom, height: r.height }];
            })
            .concat([
              [
                "transport",
                (() => {
                  const r = document
                    .querySelector(".transport")
                    .getBoundingClientRect();
                  return { top: r.top, bottom: r.bottom };
                })(),
              ],
            ]),
        ),
      );
      assert(
        boxes["detail-wave"].height >= 60,
        "FX must leave a usable waveform",
      );
      assert(
        boxes["fx-panel"].bottom <= boxes["detail-wave"].top + 1,
        "FX toolbar must precede and never overlap the waveform",
      );
      assert(
        boxes["loudness-strip"].bottom <= boxes["fx-panel"].top + 1 &&
          Math.abs(boxes["asset-info"].top - boxes["loudness-strip"].top) < 10,
        "loudness belongs beside format metadata, above the waveform/FX",
      );
      assert(
        boxes["fx-panel"].bottom <= boxes.transport.top + 1,
        "FX must not cover transport controls",
      );
      assert(
        boxes.transport.bottom <= boxes.audition.bottom + 1,
        "transport must stay inside the player",
      );
      const controls = await page.locator(".transport").evaluate((row) =>
        [
          ...row.querySelectorAll(
            ":scope > button, .transport-center > *, .transport-actions > *",
          ),
        ]
          .filter((el) => el.getClientRects().length)
          .map((el) => {
            const r = el.getBoundingClientRect();
            return {
              id: el.id || el.className,
              left: r.left,
              right: r.right,
              top: r.top,
              bottom: r.bottom,
            };
          }),
      );
      for (let i = 0; i < controls.length; i++) {
        assert(
          controls[i].left >= -1 && controls[i].right <= size.width + 1,
          `${controls[i].id} must stay in the viewport at ${size.width}px`,
        );
        for (let j = 0; j < i; j++) {
          const a = controls[i],
            b = controls[j];
          assert(
            a.left >= b.right - 1 ||
              b.left >= a.right - 1 ||
              a.top >= b.bottom - 1 ||
              b.top >= a.bottom - 1,
            `${a.id} overlaps ${b.id}`,
          );
        }
      }
      const center = await page.locator(".transport-center").boundingBox();
      assert(
        Math.abs(center.x + center.width / 2 - size.width / 2) < 2,
        "transport group stays centered",
      );
      const activity = await page.locator("#activity-status").boundingBox();
      assert(
        activity.x <= 15,
        "activity stays at bottom left inside the player padding",
      );
      if (size.height === 620) {
        const rail = page.locator("#navigation-rail");
        assert.equal(
          await rail.evaluate((el) => getComputedStyle(el).overflowY),
          "auto",
          "short windows must allow access to every navigation icon",
        );
        await page
          .locator('[data-rail="collections"]')
          .scrollIntoViewIfNeeded();
        const railBox = await rail.boundingBox();
        const lastIcon = await page
          .locator('[data-rail="collections"]')
          .boundingBox();
        assert(lastIcon.y + lastIcon.height <= railBox.y + railBox.height + 1);
        await rail.evaluate((el) => {
          el.scrollTop = 0;
        });
      }
      await page.screenshot({
        path: path.join(output, `beta10-fx-${size.width}.png`),
      });
    }
    await page.setViewportSize({ width: 1600, height: 1000 });
    const playerGrip = await page.locator("#audition-splitter").boundingBox();
    await page.mouse.move(playerGrip.x + 50, playerGrip.y + 2);
    await page.mouse.down();
    await page.mouse.move(playerGrip.x + 50, playerGrip.y + 320, { steps: 8 });
    await page.mouse.up();
    assert(
      (await page.locator("#audition").boundingBox()).height < 300,
      "FX player must shrink below the previous 390px floor",
    );
    assert((await page.locator("#detail-wave").boundingBox()).height >= 60);
    const transportBox = await page.locator(".transport").boundingBox();
    const smallPlayer = await page.locator("#audition").boundingBox();
    assert(
      transportBox.y + transportBox.height <=
        smallPlayer.y + smallPlayer.height,
      "minimum height keeps transport accessible",
    );
    await page.screenshot({ path: path.join(output, "beta10-compact-fx.png") });
    const volumeBox = await page.locator(".transport-volume").boundingBox();
    const loopBox = await page.locator("#loop").boundingBox();
    assert(volumeBox.x > loopBox.x && Math.abs(volumeBox.y - loopBox.y) < 6);
    await page.locator("#fx-gain-value").fill("");
    await page
      .locator("#fx-gain-value")
      .pressSequentially("-8.6", { delay: 15 });
    assert.equal(
      await page.locator("#fx-gain-value").inputValue(),
      "-8.6",
      "signed decimal values must remain editable",
    );
    await page.waitForFunction(() =>
      window.testCalls.some(
        (c) => c.method === "preview.parameters" && c.params.gain_db === -8.6,
      ),
    );
    await page.locator("#fx-gain").dblclick();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (c) => c.method === "preview.parameters" && c.params.gain_db === 0,
      ),
    );
    await page.evaluate(() =>
      window.testSetState({ regionStart: 0.1, regionEnd: 0.8 }),
    );
    await page.locator("#range-label").click();
    await page.locator('.selection-editor input[name="start"]').fill("1");
    await page.locator('.selection-editor input[name="finish"]').fill("0.5");
    await page.locator('.selection-editor button[type="submit"]').click();
    assert(
      await page.locator(".selection-editor").isVisible(),
      "invalid ranges must remain editable",
    );
    await page.locator('.selection-editor input[name="finish"]').fill("3");
    await page.locator('.selection-editor button[type="submit"]').click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (c) =>
          c.method === "preview.region" &&
          c.params.path &&
          c.params.finish > c.params.start,
      ),
    );
    await page.locator("#fx-presets").click();
    await page.getByRole("button", { name: "音高预设", exact: false }).click();
    await page.getByRole("button", { name: "+6 st", exact: true }).click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (c) => c.method === "preview.parameters" && c.params.pitch === 6,
      ),
    );
    await page.locator("#audition-more").click();
    await page
      .getByRole("button", { name: "清除波形选区", exact: true })
      .click();
    await page.waitForFunction(() =>
      window.testCalls.some((c) => c.method === "preview.clearRegion"),
    );
    await page.locator("#fx-toggle").click();
    assert(
      await page.locator("#fx-gain").isVisible(),
      "volume remains available with FX closed",
    );
    await page.evaluate(() =>
      window.testSetState({ tasks: {}, similarityProgress: undefined }),
    );
    await page.setViewportSize({ width: 1000, height: 720 });
    await page.addInitScript(() => {
      Object.defineProperty(window, "reaper", {
        value: {
          lifecycle: {
            ready: Promise.resolve({
              protocol: 1,
              version:
                new URLSearchParams(location.search).get("runtimeVersion") ||
                "0.3.9.30",
              runtime: {
                contract: Number(
                  new URLSearchParams(location.search).get("runtimeContract") ||
                    2,
                ),
                host: { maxMessageBytes: 1048576 },
              },
              webRuntime: { contract: 1 },
            }),
          },
          window: {
            getState: async () => ({
              dawKeyboard: window.testKeyboardPolicy.findLast(
                ([key]) => key === "daw",
              )?.[1],
              shortcutRouting: window.testKeyboardPolicy.findLast(
                ([key]) => key === "shortcuts",
              )?.[1],
              keyboardCapture: window.testKeyboardPolicy.findLast(
                ([key]) => key === "capture",
              )?.[1],
            }),
            setDawKeyboard: async (value) => {
              (window.testKeyboardPolicy ||= []).push(["daw", value]);
              return value;
            },
            setShortcutRouting: async (value) => {
              (window.testKeyboardPolicy ||= []).push(["shortcuts", value]);
              return value;
            },
            setKeyboardCapture: async (value) => {
              (window.testKeyboardPolicy ||= []).push(["capture", value]);
              return value;
            },
          },
          host: {
            send(message) {
              function validate(value) {
                if (
                  value === undefined ||
                  typeof value === "function" ||
                  (typeof value === "number" && !Number.isFinite(value))
                )
                  throw new Error("Expected a JSON-serializable value");
                if (value && typeof value === "object")
                  Object.values(value).forEach(validate);
              }
              validate(message);
              window.chrome.webview.postMessage(message);
              return Promise.resolve(true);
            },
          },
          events: {
            on(_name, callback) {
              if (_name === "native-drop") {
                window.testNativeDrop = callback;
                return Promise.resolve(() => {
                  window.testNativeDrop = null;
                });
              }
              window.chrome.webview.addEventListener("message", (event) =>
                callback(JSON.stringify(event.data)),
              );
              return Promise.resolve(() => {
                window.testDisposed = true;
              });
            },
          },
          dragDrop: { startFiles: () => Promise.resolve(true) },
          system: { revealInFileManager: () => Promise.resolve(true) },
        },
      });
    });
    await page.reload();
    await page.waitForSelector(".result-row");
    assert.equal(await page.locator("#host-label").count(), 0);
    await page.locator("#settings-open").click();
    await page.locator('[data-section="about"]').click();
    assert.match(
      await page.locator("#settings-body").textContent(),
      /ReaWebAPI 0.3.9.30/,
    );
    await page.locator("#settings-close").click();
    assert.deepEqual(
      await page.evaluate(() => window.testKeyboardPolicy),
      [
        ["daw", false],
        ["shortcuts", false],
        ["capture", true],
      ],
      "native Space/Main routing must be explicitly disabled on every connection",
    );
    await page.waitForFunction(
      () => typeof window.testNativeDrop === "function",
    );
    await page.locator('[data-rail="libraries"]').click();
    const source = page
      .locator("#libraries > .library-branch > .folder-branch")
      .first();
    if (!(await source.evaluate((el) => el.open)))
      await source.locator(":scope > summary > .folder-toggle").click();
    await source.locator(".folder-branch").first().waitFor();
    const target = source
      .locator(".folder-branch > summary > .nav-item")
      .first();
    const targetBox = await target.boundingBox();
    const owner = await target.evaluate(
      (el) => el.closest("[data-library-id]").dataset.libraryId,
    );
    await page.evaluate(
      ({ x, y }) => window.testNativeDrop({ files: ["D:\\New source"], x, y }),
      { x: targetBox.x + 10, y: targetBox.y + 10 },
    );
    await page.waitForFunction(
      (id) =>
        window.testCalls.some(
          (c) => c.method === "library.drop" && c.params.libraryId === id,
        ),
      owner,
    );
    assert.equal(
      await page.locator("dialog[open]").count(),
      0,
      "dropping on a child folder must add a source to its library",
    );
    await page.evaluate(() =>
      window.testNativeDrop({
        files: ["D:\\Library A", "D:\\Library B"],
        x: 600,
        y: 200,
      }),
    );
    await page
      .getByRole("button", { name: "合并到一个音效库", exact: true })
      .click();
    await page.waitForFunction(() =>
      window.testCalls.some(
        (call) =>
          call.method === "library.drop" &&
          call.params.paths.length === 2 &&
          call.params.separate === false,
      ),
    );
    await page.locator(".result-cell.name").first().click();
    await page.waitForFunction(() =>
      window.testCalls.some((call) => call.method === "selection.set"),
    );
    await page.locator("#settings-open").click();
    await page.waitForSelector("#settings-dialog[open]", { timeout: 3000 });
    await page.getByRole("button", { name: "关闭设置" }).click();
    await page.locator('[data-inspector="regions"]').click();
    await page.locator('[data-inspector="transfer"]').click();
    await page
      .locator('#inspector-body input[data-field="transfer_dir"]')
      .waitFor();
    await page.locator('[data-inspector="metadata"]').click();
    await page.locator("#loop").click();
    await page.locator("#stop").click();
    await page.locator("#new-tab").click();
    assert.equal(
      await page.locator("#status.error").count(),
      0,
      "native transport interactions must not report serialization failures",
    );
    await page.addInitScript(() => {
      const fixture = new URL(location.href).searchParams.get("themeFixture");
      if (fixture) localStorage.setItem("psyreasfx.workspace.v1", fixture);
    });
    for (const migration of [
      {
        themeColorsVersion: 1,
        surfaceColor: "#e8edf5",
        accentColor: "#345d9d",
        expectedSurface: "#f7f7f7",
        expectedAccent: "#0969da",
      },
      {
        themeColorsVersion: 1,
        surfaceColor: "#d4ded8",
        accentColor: "#c7b57f",
        expectedSurface: "#d4ded8",
        expectedAccent: "#c7b57f",
      },
      {
        themeColorsVersion: 0,
        surfaceColor: "#222426",
        accentColor: "#c7b57f",
        expectedSurface: "#f7f7f7",
        expectedAccent: "#0969da",
      },
    ]) {
      const migrationUrl = new URL(page.url());
      migrationUrl.searchParams.set(
        "themeFixture",
        JSON.stringify({ version: 1, theme: "frost", ...migration }),
      );
      // Seed after the old page's unload persistence has completed.
      await page.goto(migrationUrl.toString());
      await page.waitForSelector(".result-row");
      const colors = await page.locator("body").evaluate((body) => ({
        surface: getComputedStyle(body).getPropertyValue("--surface").trim(),
        accent: getComputedStyle(body).getPropertyValue("--accent").trim(),
      }));
      assert.deepEqual(
        colors,
        {
          surface: migration.expectedSurface,
          accent: migration.expectedAccent,
        },
        "migrate old defaults without overwriting custom colors",
      );
    }
    const url = new URL(page.url());
    url.searchParams.delete("themeFixture");
    url.searchParams.set("runtimeVersion", "0.4.0");
    await page.goto(url.toString());
    await page.waitForSelector(".result-row");
    await page.locator("#settings-open").click();
    await page.locator('[data-section="about"]').click();
    assert.match(
      await page.locator("#settings-body").textContent(),
      /0.4.0.*外部版本/,
    );
    await page.locator("#settings-close").click();
    url.searchParams.set("runtimeContract", "99");
    await page.goto(url.toString());
    await page.waitForFunction(() => window.testDisposed === true);
    assert.equal(await page.locator("#result-count").textContent(), "等待宿主");
    assert.equal(
      await page.locator(".result-row").count(),
      0,
      "incompatible contracts must stop the connection",
    );
    assert.deepEqual(errors, [], "UI must not raise JavaScript errors");
    console.log(
      "WebView UI verified: bounded 500k viewport, full-width waveform, menus, startup/settings drafts and retries, AI drafts, Transfer drafts, task cancellation, localization, theme persistence",
    );
    console.log(output);
  } finally {
    await browser?.close();
    await new Promise((resolve) => server.close(resolve));
  }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
