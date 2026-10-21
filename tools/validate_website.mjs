import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const toolsDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.dirname(toolsDirectory);
const websiteRoot = path.join(repositoryRoot, "website");
const htmlPath = path.join(websiteRoot, "index.html");
const scriptPath = path.join(websiteRoot, "app.js");
const html = fs.readFileSync(htmlPath, "utf8");
const script = fs.readFileSync(scriptPath, "utf8");
const failures = [];

function fail(message) {
  failures.push(message);
}

const sandbox = {
  document: {
    addEventListener() {},
    querySelector() { return null; },
    querySelectorAll() { return []; },
  },
  console,
};
vm.runInNewContext(`${script}\n;globalThis.__messages = messages;`, sandbox, {
  filename: scriptPath,
});

try {
  vm.runInNewContext(`
    updateReleaseLink("[data-test]", null, { url: "https://example.com/fallback" });
    if (formatReleaseVersion("v0.9.0-beta7") !== "0.9.0 Beta 7") {
      throw new Error("Release tag formatting failed");
    }
  `, sandbox, { filename: scriptPath });
} catch (error) {
  fail(`Website runtime smoke test failed: ${error.message}`);
}

const messages = sandbox.__messages;
if (!messages?.en || !messages?.zh) fail("app.js must define en and zh messages");

const translationKeys = new Set();
for (const match of html.matchAll(/data-i18n(?:-aria-label)?="([^"]+)"/g)) {
  translationKeys.add(match[1]);
}
for (const key of translationKeys) {
  if (typeof messages?.en?.[key] !== "string") fail(`Missing English translation: ${key}`);
  if (typeof messages?.zh?.[key] !== "string") fail(`Missing Chinese translation: ${key}`);
}

const ids = new Set();
const projectHomeLinks = [...html.matchAll(/<a\b([^>]*\bdata-project-home\b[^>]*)>([\s\S]*?)<\/a>/g)];
if (projectHomeLinks.length !== 4) fail("Project homepage must have text links in navigation, hero, installation and footer");
for (const [, attributes, label] of projectHomeLinks) {
  if (!attributes.includes('href="https://github.com/Psysia/PsyReaSFX"')
    || !attributes.includes('data-i18n="projectHome"') || !label.trim()) {
    fail("Project homepage entry must be a labeled link to the repository root");
  }
}
if (!/<nav[^>]*>\s*<a class="project-home-link" data-project-home/.test(html)) {
  fail("Project homepage entry must be first in navigation for mobile discoverability");
}
for (const match of html.matchAll(/\bid="([^"]+)"/g)) {
  if (ids.has(match[1])) fail(`Duplicate HTML id: ${match[1]}`);
  ids.add(match[1]);
}

const localReferences = new Set();
for (const match of html.matchAll(/\b(?:src|href)="([^"]+)"/g)) {
  localReferences.add(match[1]);
}
for (const match of html.matchAll(/\bsrcset="([^"]+)"/g)) {
  for (const candidate of match[1].split(",")) {
    localReferences.add(candidate.trim().split(/\s+/)[0]);
  }
}
for (const reference of localReferences) {
  if (!reference || reference.startsWith("#") || /^[a-z]+:/i.test(reference)) continue;
  const localPath = path.resolve(websiteRoot, reference.split(/[?#]/)[0]);
  if (!localPath.startsWith(websiteRoot + path.sep) || !fs.existsSync(localPath)) {
    fail(`Missing or unsafe local resource: ${reference}`);
  }
}

for (const required of [
  'rel="canonical"',
  'property="og:image"',
  'name="twitter:card"',
  'rel="manifest"',
  'data-stable-download',
  'data-preview-download',
  'data-neural-download',
  'id="beta-install"',
  'id="version-comparison"',
  'id="neural-install"',
  'assets/screenshots/reapack-enable-beta.jpg',
]) {
  if (!html.includes(required)) fail(`Missing required homepage marker: ${required}`);
}

const neuralZipPattern = /^https:\/\/github\.com\/Psysia\/PsyReaSFX\/releases\/download\/v[\d.]+-beta[\d.]+\/PsyReaSFX_Neural_Similarity_v[\d_]+_beta[\d_]+_win_x64\.zip$/;
const fallbackNeuralUrl = vm.runInNewContext("NEURAL_FALLBACK_URL", sandbox);
if (!neuralZipPattern.test(fallbackNeuralUrl)) fail("Neural fallback must be a complete release ZIP");
for (const source of [html, ...Object.values(messages.en), ...Object.values(messages.zh)]) {
  for (const match of source.matchAll(/<a\b([^>]*\bdata-neural-download\b[^>]*)>/g)) {
    const href = match[1].match(/\bhref="([^"]+)"/)?.[1];
    if (href !== fallbackNeuralUrl) fail(`Neural download link must target the verified ZIP: ${href}`);
  }
}

try {
  const links = [{ href: "" }];
  const languageElement = {
    dataset: { i18n: "compareAddon" },
    set innerHTML(value) {
      // Model a language switch replacing the nested download link.
      links[0].href = value.match(/href="([^"]+)"/)?.[1] || "";
    },
  };
  sandbox.document.documentElement = {};
  sandbox.document.querySelectorAll = (selector) =>
    selector === "[data-neural-download]" ? links
      : selector === "[data-i18n]" ? [languageElement] : [];
  sandbox.localStorage = { setItem() {} };
  sandbox.__neuralFixture = {
    assets: [
      { name: "PsyReaSFX_v0_9_0_beta99_1.zip", browser_download_url: "https://example.com/lua.zip" },
      { name: "PsyReaSFX.NeuralSidecar_v0_9_0_beta99_1_win_x64.exe", browser_download_url: "https://example.com/bare.exe" },
      {
        name: "PsyReaSFX_Neural_Similarity_v0_9_0_beta99_1_win_x64.zip",
        browser_download_url: fallbackNeuralUrl.replace(/-beta[\d.]+\//, "-beta99.1/")
          .replace(/_beta[\d_]+_win_x64/, "_beta99_1_win_x64"),
      },
    ],
  };
  vm.runInNewContext(`
    updateNeuralDownload(null);
    if (neuralDownloadUrl !== NEURAL_FALLBACK_URL) throw new Error("Missing release must keep ZIP fallback");
    updateNeuralDownload(__neuralFixture);
    if (neuralDownloadUrl !== __neuralFixture.assets[2].browser_download_url) throw new Error("Wrong neural asset");
    applyLanguage("zh");
    applyLanguage("en");
    updateNeuralDownload({ assets: [__neuralFixture.assets[0], __neuralFixture.assets[1]] });
  `, sandbox);
  if (links[0].href !== sandbox.__neuralFixture.assets[2].browser_download_url) {
    throw new Error("Language switching or Lua-only release lost the complete neural ZIP");
  }
} catch (error) {
  fail(`Neural download runtime regression failed: ${error.message}`);
}

for (const relative of [
  "README.md", "README_zh-CN.md", "docs/USER_GUIDE_en-US.md", "docs/USER_GUIDE_zh-CN.md",
  "neural/README.md", "neural/package/README.md", "neural/package/README_zh-CN.md",
  "docs/CHANGELOG_en-US.md", "docs/CHANGELOG_zh-CN.md",
  "docs/NEURAL_SIMILARITY_ARCHITECTURE_0_9_zh-CN.md", "docs/ROADMAP_0_9_TO_1_0_zh-CN.md",
]) {
  const markdown = fs.readFileSync(path.join(repositoryRoot, relative), "utf8");
  const references = markdown.match(/^\[neural-download\]: (.+)$/gm) || [];
  if (references.length !== 1 || references[0] !== `[neural-download]: ${fallbackNeuralUrl}`) {
    fail(`Missing or stale precise neural download reference: ${relative}`);
  }
  if (/\x60PsyReaSFX Neural Similarity\x60|\*\*PsyReaSFX Neural Similarity\*\*/.test(markdown)) {
    fail(`Unlinked neural package mention: ${relative}`);
  }
  if (/\[[^\]\n]*\[[^\]\n]*\]\[neural-download\]\]\(/.test(markdown)) {
    fail(`Nested neural download link: ${relative}`);
  }
}

const reapackIndex = fs.readFileSync(path.join(repositoryRoot, "index.xml"), "utf8");
for (const match of reapackIndex.matchAll(/<source[^>]*file="PsyReaSFX\/neural_similarity\/(README(?:_zh-CN)?\.md)"[^>]*hash="1220([a-f0-9]{64})"[^>]*>([^<]+)<\/source>/g)) {
  const digest = crypto.createHash("sha256")
    .update(fs.readFileSync(path.join(repositoryRoot, "neural/package", match[1]))).digest("hex");
  if (digest !== match[2]) fail(`ReaPack documentation hash mismatch: ${match[1]}`);
  if (!/^https:\/\/raw\.githubusercontent\.com\/Psysia\/PsyReaSFX\/[a-f0-9]{40}\/neural\/package\//.test(match[3])) {
    fail(`Neural installer documentation must use an immutable commit URL: ${match[1]}`);
  }
}
for (const name of ["PsyReaSFX.lua", "PsyReaSFX Neural Similarity"]) {
  const metadata = reapackIndex.match(
    new RegExp(`<reapack name="${name.replace(".", "\\.")}"[^>]*>\\s*<metadata>([\\s\\S]*?)<\\/metadata>`),
  )?.[1];
  if (!metadata?.includes(`href="${fallbackNeuralUrl}"`)) {
    fail(`ReaPack package metadata needs the complete ZIP download: ${name}`);
  }
}

const comparison = html.match(/<table class="comparison-table">([\s\S]*?)<\/table>/)?.[1];
if (!comparison || (comparison.match(/scope="row"/g) || []).length !== 10) {
  fail("Version comparison must contain all ten documented feature rows");
}
for (const match of html.matchAll(/\bhref="#([^"]+)"/g)) {
  if (!ids.has(match[1])) fail(`Missing local anchor: #${match[1]}`);
}

// Archive versions may be documented in installation notes, but must not
// become the default stable download again.
if (/Alpha_1_win_x64/.test(html + script)
  || /const STABLE_FALLBACK\s*=\s*\{[^}]*version:\s*"0\.7\.23"/.test(script)
  || /data-stable-version[^>]*>\s*0\.7\.23/.test(html)) {
  fail("Website contains a stale release fallback");
}

for (const file of ["robots.txt", "sitemap.xml", "site.webmanifest"]) {
  if (!fs.existsSync(path.join(websiteRoot, file))) fail(`Missing website metadata file: ${file}`);
}
JSON.parse(fs.readFileSync(path.join(websiteRoot, "site.webmanifest"), "utf8"));

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  `Website validation passed: ${translationKeys.size} translated keys, ${localReferences.size} local/link references`,
);
