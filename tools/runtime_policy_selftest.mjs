import assert from "node:assert/strict";
import { connectHost } from "../src/web/host.js";

// Exercise the real handshake, including the settings/about status returned to
// the UI. An old patched DLL must not look current merely because its ABI fits.
const policy = {
  protocol: 1,
  runtime_contracts: [2],
  web_contracts: [1],
  minimum_message_bytes: 900000,
  baseline_versions: ["0.3.9.30-prs.2"],
  validation_status: "native_acceptance_pending",
};
for (const [version, status] of [
  ["0.3.9.29", "dock_patch_required"],
  ["0.3.9.30-prs.1", "dock_patch_required"],
  ["0.3.9.32", "dock_patch_required"],
  ["0.3.9.30-prs.2", "native_acceptance_pending"],
  ["0.3.9.99", "external_unverified"],
]) {
  let receive;
  let disposed = false;
  globalThis.window = {
    reaper: {
      lifecycle: {
        ready: Promise.resolve({
          version,
          protocol: 1,
          runtime: { contract: 2, host: { maxMessageBytes: 1048576 } },
          webRuntime: { contract: 1 },
        }),
      },
      window: {
        async setDawKeyboard() {},
        async setShortcutRouting() {},
        async setKeyboardCapture() {},
        async getState() {
          return {
            dawKeyboard: false,
            shortcutRouting: false,
            keyboardCapture: true,
          };
        },
      },
      events: {
        async on(name, callback) {
          assert.equal(name, "message");
          receive = callback;
          return () => {
            disposed = true;
          };
        },
      },
      host: {
        send(message) {
          assert.equal(message.method, "session.ready");
          receive({
            protocol: 1,
            id: message.id,
            ok: true,
            result: { protocol: 1, runtimePolicy: policy },
          });
        },
      },
    },
  };
  const connection = await connectHost();
  assert.equal(connection.runtime.status, status, version);
  if (status === "dock_patch_required")
    assert.match(connection.runtime.notice, /0\.3\.9\.30-beta3/);
  connection.close();
  assert.equal(disposed, true);
}
delete globalThis.window;
console.log(
  "Runtime handshake: old dock patch, current baseline and unknown external version passed",
);
