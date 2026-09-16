import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
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
]) {
  if (!html.includes(required)) fail(`Missing required homepage marker: ${required}`);
}

if (/0\.7\.23 Stable|Alpha_1_win_x64/.test(html + script)) {
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
