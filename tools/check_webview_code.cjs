// Usage: node tools/check_webview_code.cjs <isolated node_modules directory>
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const dependencies = path.resolve(process.argv[2] || "node_modules");
const { ESLint } = require(path.join(dependencies, "eslint"));
const globals = require(path.join(dependencies, "globals"));
const root = path.resolve(__dirname, "..");
async function main() {
  const lint = new ESLint({
    cwd: root,
    overrideConfigFile: true,
    overrideConfig: [
      {
        files: ["src/web/*.js"],
        languageOptions: {
          ecmaVersion: "latest",
          sourceType: "module",
          globals: globals.browser,
        },
        rules: {
          "no-undef": "error",
          "no-unreachable": "error",
          "no-dupe-keys": "error",
          "no-constant-condition": "error",
          "no-unexpected-multiline": "error",
        },
      },
    ],
  });
  const results = await lint.lintFiles(["src/web/*.js"]);
  const formatter = await lint.loadFormatter("stylish");
  const report = formatter.format(results);
  if (report) console.log(report);
  assert(
    !results.some((result) => result.errorCount),
    "WebView code errors must be fixed",
  );
  const files = ["index.html", "app.js", "settings.js"].map((name) =>
    fs.readFileSync(path.join(root, "src/web", name), "utf8"),
  );
  const ids = new Set(
    files.flatMap((text) =>
      [...text.matchAll(/\bid\s*=\s*"([^"]+)"/g)].map((match) => match[1]),
    ),
  );
  const missing = [
    ...new Set(
      [...files[1].matchAll(/\$\("([^"]+)"\)/g)].map((match) => match[1]),
    ),
  ].filter((id) => !ids.has(id));
  assert.deepEqual(
    missing,
    [],
    "Every static UI entry must resolve to a declared element",
  );
  const backend = fs.readFileSync(
    path.join(root, "src/lua/48_webview.lua"),
    "utf8",
  );
  const handlers = [
    ...backend.matchAll(/WebUI\.handlers\["([^"]+)"\]\s*=\s*function/g),
  ].map((match) => match[1]);
  assert.equal(
    new Set(handlers).size,
    handlers.length,
    "RPC handlers must not silently overwrite each other",
  );
  const inventory = JSON.parse(
    fs.readFileSync(
      path.join(root, "tools/webview_parity_inventory.json"),
      "utf8",
    ),
  );
  assert.equal(
    new Set(inventory.features.map((item) => item.id)).size,
    inventory.features.length,
  );
  const native = [
    "50_runtime_ui.lua",
    "11_ui_workspace.lua",
    "13_workspace_tabs.lua",
  ]
    .map((name) => fs.readFileSync(path.join(root, "src/lua", name), "utf8"))
    .join("\n");
  for (const feature of inventory.features) {
    for (const symbol of feature.source.split(";"))
      assert(
        native.includes(`function ${symbol}(`),
        `${feature.id}: missing native source ${symbol}`,
      );
    for (const rpc of feature.rpc.split(",")) {
      if (rpc === "local") continue;
      assert(handlers.includes(rpc), `${feature.id}: missing RPC ${rpc}`);
      assert(
        files.slice(1).join("\n").includes(`"${rpc}"`),
        `${feature.id}: no frontend reference to ${rpc}`,
      );
    }
  }
  const schema = backend.slice(
    backend.indexOf("local settings_schema"),
    backend.indexOf('WebUI.handlers["settings.get"]'),
  );
  const keys = [...schema.matchAll(/key = "([^"]+)"/g)]
    .map((match) => match[1])
    .sort();
  assert.deepEqual(
    inventory.settings.map((item) => item.key).sort(),
    keys,
    "Every host setting needs a parity checklist entry",
  );
  console.log(
    `WebView static checks passed: ${ids.size} UI elements, ${handlers.length} unique RPC handlers`,
  );
  console.log(
    `Source parity inventory checked: ${inventory.features.length} features and ${keys.length} settings`,
  );
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
