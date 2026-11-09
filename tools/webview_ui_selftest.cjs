// Run with a Playwright installation path, keeping browser tooling outside the app package.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { chromium } = require(process.argv[2] || "playwright");
const root = path.resolve(__dirname, "../src/web");
const displayVersion = JSON.parse(
  fs.readFileSync(path.join(root, "app.json"), "utf8"),
).version.replace("-beta", " Beta ");
const output = path.resolve(__dirname, "../dist/webview/verification");

async function main() {
  const server = http.createServer((request, response) => {
    const pathname = decodeURIComponent(
      new URL(request.url, "http://localhost").pathname,
    );
    const file = path.resolve(
      root,
      "." + (pathname === "/" ? "/index.html" : pathname),
    );
    if (!file.startsWith(root + path.sep) || !fs.existsSync(file)) {
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
      const calls = [];
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
          name: `${names[(index - 1) % names.length]} ${String(index).padStart(2, "0")}.wav`,
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
          },
          position: 0.24,
          regionStart: 0.12,
          regionEnd: 0.5,
          fx,
          tasks: {},
          aiHasMore: false,
        };
      }
      window.chrome = {
        webview: {
          addEventListener(name, callback) {
            listener = callback;
          },
          removeEventListener() {},
          postMessage(request) {
            calls.push(request);
            if (request.method === "settings.get" && window.testSettingsError) {
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
            if (request.method === "management.get") result = [];
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
            if (request.method === "preview.play" && selected) {
              played.add(selected.index);
              playingPath = selected.path;
            }
            if (request.method === "preview.stop") playingPath = null;
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
              selected = asset(request.params.index);
              result = selected;
            }
            if (request.method === "waveform.get")
              result = {
                path: request.params.path,
                duration: selected?.duration || 8.24,
                waveform: {
                  count: 1024,
                  peaks: detailPeaks,
                  channels: [detailPeaks, detailPeaks],
                },
              };
            if (request.method === "catalog.query") {
              count = 125;
              revision++;
            }
            if (request.method === "preview.parameters")
              fx = { ...fx, ...request.params };
            if (request.method === "settings.get")
              result = {
                schema: [
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
                values: { played_text_enabled: playedText, language },
                transfer_dir: "D:\\Exports",
                transfer_template: "{name}",
                transfer_format: "wav24",
                transfer_sample_rate: "source",
                transfer_channels: "source",
                transfer_scope: "selection",
                auto_preview: true,
              };
            queueMicrotask(() => {
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
            });
          },
        },
      };
    }, displayVersion);
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    await page.waitForSelector(".result-row");
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
    await page.locator(".result-cell.name").nth(1).click();
    assert.equal(
      await page.locator(".result-row.played:not(.selected)").count(),
      1,
    );
    await page.locator("#settings-open").click();
    await page.waitForSelector("#settings-dialog[open]", { timeout: 3000 });
    await page
      .locator("#settings-body summary")
      .filter({ hasText: "试听颜色" })
      .click();
    await page.locator('[data-setting="played_text_enabled"]').uncheck();
    await page.waitForFunction(
      () => document.querySelectorAll(".result-row.played").length === 0,
    );
    await page.locator('[data-setting="played_text_enabled"]').check();
    await page
      .locator("#settings-body summary")
      .filter({ hasText: "常规" })
      .click();
    const originalDescription = await page
      .locator(".result-cell.description")
      .first()
      .textContent();
    await page.locator('[data-setting="language"]').selectOption("en");
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
    await page.waitForFunction(() => document.documentElement.lang === "zh-CN");
    await page.getByRole("button", { name: "关闭设置" }).click();
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
    await page.locator('#settings-body input[data-field="url"]').waitFor();
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
    await page.locator("#fx-toggle").click();
    await page.waitForSelector("#fx-pitch:visible");
    const fxWidth = await page.locator("#detail-wave").boundingBox();
    assert.equal(
      fxWidth.width,
      before.width,
      "expanded FX must keep waveform width",
    );
    await page.locator("#fx-toggle").click();
    await page.locator("#columns-open").click();
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
    await page.locator("#layout-menu").click();
    await page
      .locator("#popover label")
      .filter({ hasText: "纸白墨绿主题" })
      .locator("input")
      .check();
    await page.keyboard.press("Escape");
    await page.reload();
    await page.waitForSelector(".result-row");
    assert.equal(
      await page.locator("body").getAttribute("data-theme"),
      "paper",
      "theme choice must persist",
    );
    await page.screenshot({ path: path.join(output, "optional-paper.png") });
    await page.setViewportSize({ width: 1000, height: 720 });
    await page.screenshot({ path: path.join(output, "compact-window.png") });
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
    assert.match(
      await page.locator("#host-label").textContent(),
      /ReaWebAPI 0.3.9.30/,
      "ReaWebAPI transport must connect",
    );
    await page.waitForFunction(
      () => typeof window.testNativeDrop === "function",
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
    const url = new URL(page.url());
    url.searchParams.set("runtimeVersion", "0.4.0");
    await page.goto(url.toString());
    await page.waitForSelector(".result-row");
    assert.match(
      await page.locator("#host-label").textContent(),
      /0.4.0.*外部版本/,
    );
    url.searchParams.set("runtimeContract", "99");
    await page.goto(url.toString());
    await page.waitForFunction(() => window.testDisposed === true);
    assert.equal(await page.locator("#host-label").textContent(), "宿主未连接");
    assert.equal(
      await page.locator(".result-row").count(),
      0,
      "incompatible contracts must stop the connection",
    );
    assert.deepEqual(errors, [], "UI must not raise JavaScript errors");
    console.log(
      "WebView UI verified: bounded 500k viewport, full-width waveform across sidebar/FX changes, optional columns, search, theme persistence",
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
