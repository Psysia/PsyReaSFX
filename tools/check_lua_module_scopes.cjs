#!/usr/bin/env node
// The release build emits every module except the bootstrap inside its own
// `do ... end` block (tools/Build-LuaRelease.ps1). A top-level `local` of such
// a module is therefore invisible to later modules. This check fails when a
// later module still reads or writes a name that an earlier wrapped module
// declared as a top-level local, i.e. when the wrapped build would silently
// turn that reference into a nil global.
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const root = path.resolve(__dirname, "..");
const build = fs.readFileSync(path.join(root, "tools", "Build-LuaRelease.ps1"), "utf8");
const block = build.match(/\$modules\s*=\s*@\(([\s\S]*?)\)/);
if (!block) { console.error("module list not found in Build-LuaRelease.ps1"); process.exit(1); }
const modules = [...block[1].matchAll(/"([^"]+\.lua)"/g)].map((match) => match[1]);
if (process.argv.includes("--webview")) modules.splice(modules.length - 1, 0, "48_webview.lua");
if (modules.length < 2) { console.error("unexpected module list"); process.exit(1); }

const declared = []; // per module: Map name -> line (top-level locals)
const freeNames = []; // per module: Map name -> first line of a non-local reference

for (const name of modules) {
  const source = fs.readFileSync(path.join(root, "src", "lua", name), "utf8");
  const ast = luaparse.parse(source, { luaVersion: "5.3", scope: true, locations: true });
  const tops = new Map();
  for (const statement of ast.body) {
    if (statement.type === "LocalStatement") {
      for (const variable of statement.variables) tops.set(variable.name, variable.loc.start.line);
    } else if (statement.type === "FunctionDeclaration" && statement.isLocal && statement.identifier) {
      tops.set(statement.identifier.name, statement.loc.start.line);
    }
  }
  declared.push(tops);

  const free = new Map();
  (function walk(node) {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) { node.forEach(walk); return; }
    if (node.type === "Identifier" && node.isLocal === false && !free.has(node.name)) {
      free.set(node.name, node.loc.start.line);
    }
    for (const key of Object.keys(node)) {
      if (key !== "loc" && key !== "range") walk(node[key]);
    }
  })(ast);
  freeNames.push(free);
}

const problems = [];
// Module 0 (bootstrap) is not wrapped, so its locals stay visible everywhere.
for (let owner = 1; owner < modules.length; owner++) {
  for (const [localName, line] of declared[owner]) {
    for (let user = 1; user < modules.length; user++) {
      if (user === owner) continue;
      if (freeNames[user].has(localName)) {
        problems.push(
          `${modules[user]}:${freeNames[user].get(localName)} uses '${localName}', ` +
          `a top-level local of ${modules[owner]}:${line}; make it a global`
        );
      }
    }
  }
}

if (problems.length > 0) {
  console.error("Lua module scope check failed:\n  " + problems.join("\n  "));
  process.exit(1);
}
let wrappedLocals = 0;
for (let index = 1; index < declared.length; index++) wrappedLocals += declared[index].size;
console.log(`Lua module scope check passed: ${modules.length} modules, ` +
  `${wrappedLocals} wrapped top-level locals, none visible to later modules`);
