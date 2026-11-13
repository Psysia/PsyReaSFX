import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/web/host.js", import.meta.url), "utf8");
const { HostConnection } = await import(
  `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
);
const tick = () => new Promise((resolve) => queueMicrotask(resolve));

// Closing a document before its send microtask must not execute a host mutation.
{
  const sent = [];
  const connection = new HostConnection((message) => sent.push(message));
  const request = connection.request("metadata.save", { values: { notes: "draft" } });
  const rejected = assert.rejects(request, /关闭/);
  connection.close();
  await rejected;
  await tick();
  assert.equal(sent.length, 0, "closed documents must not submit queued mutations");
  let states = 0;
  connection.addEventListener("state", () => states++);
  connection.receive({ protocol: 1, event: "state", data: { count: 1 } });
  assert.equal(states, 0, "late state messages must not revive a closed document");
}

// Capture parameters at the call boundary, including false and zero.
{
  let sent;
  const connection = new HostConnection((message) => { sent = message; });
  const params = { pitch: 0, reverse: false, optional: undefined };
  const request = connection.request("preview.parameters", params);
  params.pitch = 12;
  await tick();
  assert.deepEqual(sent.params, { pitch: 0, reverse: false });
  connection.receive({ protocol: 1, id: sent.id, ok: true, result: 0 });
  assert.equal(await request, 0);
  assert.equal(connection.pending.size, 0);
  connection.close();
}

// Ignore malformed responses/events without losing a live request.
{
  let sent;
  const connection = new HostConnection((message) => { sent = message; });
  const request = connection.request("catalog.page");
  await tick();
  let states = 0;
  connection.addEventListener("state", () => states++);
  for (const data of [null, false, "bad", []])
    connection.receive({ protocol: 1, event: "state", data });
  connection.receive("{bad json");
  connection.receive({ protocol: 2, id: sent.id, ok: true });
  connection.receive({ protocol: 1, id: sent.id, ok: "false" });
  assert.equal(states, 0);
  assert.equal(connection.pending.size, 1, "malformed messages must not settle requests");
  connection.receive({ protocol: 1, event: "state", data: { count: 2 } });
  assert.equal(states, 1);
  connection.receive({ protocol: 1, id: sent.id, ok: false, error: "fixture failure" });
  await assert.rejects(request, /fixture failure/);
  connection.close();
}

// Browsing congestion must leave bounded room for Stop and Cancel.
{
  const sent = [];
  const connection = new HostConnection((message) => sent.push(message));
  const reads = Array.from({ length: 28 }, () => connection.request("catalog.page").catch(() => null));
  await assert.rejects(connection.request("catalog.page"), /排队/);
  const stop = connection.request("preview.stop");
  const cancel = connection.request("tasks.cancel", { task: "transfer" });
  await tick();
  for (const message of sent)
    connection.receive({ protocol: 1, id: message.id, ok: true, result: true });
  assert.equal(await stop, true);
  assert.equal(await cancel, true);
  await Promise.all(reads);
  assert.equal(connection.pending.size, 0);
  connection.close();
}

// Transport/serialization failures release capacity and report an error.
{
  const connection = new HostConnection(() => { throw new Error("offline"); });
  await assert.rejects(connection.request("catalog.page"), /offline/);
  assert.equal(connection.pending.size, 0);
  const cyclic = {}; cyclic.self = cyclic;
  await assert.rejects(connection.request("metadata.save", cyclic));
  await assert.rejects(connection.request("metadata.save", { text: "测".repeat(310000) }), /过大/);
  assert.equal(connection.pending.size, 0);
  connection.close();
}

console.log("Host connection passed: close/send races, immutable parameters, message validation, stop/cancel capacity and failure cleanup");
