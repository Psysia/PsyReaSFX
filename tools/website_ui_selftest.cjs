// Website release routing and responsive navigation. Uses the existing browser toolchain.
const assert = require("node:assert/strict");
const path = require("node:path");
const fs = require("node:fs");
const http = require("node:http");
const { chromium } = require(process.argv[2] || "playwright");
let url = process.argv[3];
const output = path.resolve(__dirname, "../dist/beta12-design/website");
fs.mkdirSync(output, { recursive: true });
(async () => {
  let browser, server;
  try {
    if (!url) {
      const root = path.resolve(__dirname, "../website");
      server = http.createServer((request, response) => {
        const pathname = decodeURIComponent(
          new URL(request.url, "http://localhost").pathname,
        );
        const file = path.resolve(
          root,
          "." + (pathname === "/" ? "/index.html" : pathname),
        );
        if (
          !file.startsWith(root + path.sep) ||
          !fs.existsSync(file) ||
          !fs.statSync(file).isFile()
        )
          return response.writeHead(404).end();
        response.setHeader(
          "Content-Type",
          {
            ".html": "text/html",
            ".js": "text/javascript",
            ".css": "text/css",
            ".png": "image/png",
            ".gif": "image/gif",
            ".webp": "image/webp",
            ".jpg": "image/jpeg",
          }[path.extname(file)] || "application/octet-stream",
        );
        fs.createReadStream(file).pipe(response);
      });
      await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
      url = `http://127.0.0.1:${server.address().port}/`;
    }
    browser = await chromium.launch({
      headless: true,
      channel: process.env.PSYREASFX_BROWSER || "msedge",
    });
    const page = await browser.newPage({
      viewport: { width: 1440, height: 1000 },
    });
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.route("https://api.github.com/**", (route) =>
      route.fulfill({
        json: [
          {
            tag_name: "v0.9.3-beta12",
            prerelease: true,
            html_url:
              "https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.3-beta12",
            assets: [
              {
                name: "PsyReaSFX_WebView_0.9.3-beta12_win_x64.zip",
                browser_download_url:
                  "https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.3-beta12/PsyReaSFX_WebView_0.9.3-beta12_win_x64.zip",
              },
            ],
          },
          { tag_name: "v0.9.2-beta4", prerelease: true, assets: [] },
          { tag_name: "v0.9.1", prerelease: false, assets: [] },
        ],
      }),
    );
    await page.goto(url);
    await page.waitForFunction(
      () => document.querySelector(".hero-visual img")?.naturalWidth > 0,
    );
    assert.equal(
      await page.locator(".hero-visual img").getAttribute("src"),
      "assets/showcase/prs-webview-beta11.png",
    );
    for (const lang of ["en", "zh"]) {
      await page.evaluate((lang) => applyLanguage(lang), lang);
      for (const width of [1440, 390]) {
        await page.setViewportSize({ width, height: 1000 });
        await page.evaluate(() => scrollTo(0, 0));
        assert(
          await page.evaluate(
            () => document.documentElement.scrollWidth <= innerWidth + 1,
          ),
          "page must not overflow horizontally",
        );
        const labels = await page
          .locator("[data-stable-version]")
          .allTextContents();
        assert(
          labels.every((label) => label === "0.9.1"),
          "WebView must never replace the stable version",
        );
        assert(
          (
            await page
              .locator("[data-webview-download]")
              .first()
              .getAttribute("href")
          ).endsWith("0.9.3-beta12_win_x64.zip"),
        );
        const shot = await page.locator(".hero-visual img").boundingBox();
        assert(
          Math.abs(shot.width / shot.height - 1846 / 1026) < 0.01,
          "product screenshot must not be cropped or stretched",
        );
        await page.screenshot({
          path: path.join(output, `home-${lang}-${width}.png`),
          fullPage: false,
        });
      }
    }
    await page.locator(".tool-more summary").click();
    assert.equal(await page.locator(".tool-more").getAttribute("open"), "");
    assert.equal(await page.locator(".script-card").count(), 12);
    assert.equal(await page.locator(".comparison-table tbody tr").count(), 13);
    await page.setViewportSize({ width: 1440, height: 1000 });
    for (const section of ["status", "version-comparison", "beta-install"]) {
      await page
        .locator("#" + section)
        .screenshot({ path: path.join(output, section + ".png") });
    }
    assert(
      await page
        .locator("#beta-install")
        .textContent()
        .then((s) => s.includes("ReaWebAPI")),
    );
    assert.deepEqual(errors, []);
    console.log(
      "Website browser checks passed: bilingual layouts, uncropped screenshot, release channels, expanded tool gallery and install guide.",
    );
  } finally {
    if (browser) await browser.close();
    if (server) await new Promise((resolve) => server.close(resolve));
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
