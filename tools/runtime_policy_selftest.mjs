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
  distribution_channel: "stable",
  distribution_binary_sha256: "b29f5f794fbde6e1abedacb06a7538ef1c62837b639b678f56266de140224c30",
};
for (const [version, status, protection = false, shared = false] of [
  ["0.3.9.29", "dock_patch_required"],
  ["0.3.9.30-prs.1", "dock_patch_required"],
  ["0.3.9.32", "dock_patch_required"],
  ["0.3.9.30-prs.2", "native_acceptance_pending"],
  ["0.3.9.99", "external_unverified"],
  ["0.3.9.30-prs.2", "shared_read_required", true, false],
  ["0.3.9.30-prs.3", "external_unverified", true, true],
]) {
  let receive;
  let disposed = false;
  let artworkPolls = 0;
  const artworkReads = [];
  globalThis.window = {
    reaper: {
      fs: {
        async stat(path) {
          artworkReads.push(path);
          return { exists: true, size: 4 };
        },
        async readFile(path) {
          artworkReads.push(path);
          return new Uint8Array([1, 2, 3, 4]);
        },
      },
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
          let result;
          if (message.method === "artwork.prepare") {
            assert.equal(message.params.path, "D:/Soundminer/cover.png");
            if (!shared) {
              receive({protocol: 1, id: message.id, ok: false, error: "shared reader required"});
              return;
            }
            result = artworkPolls++ === 0 ? { pending: true } : { path: "C:/PRS/native_media/cover.png" };
          } else {
            assert.equal(message.method, "session.ready");
            result = { protocol: 1, runtimePolicy: policy, sourceProtection: protection, capabilities: { sharedSourceReads: shared } };
          }
          receive({
            protocol: 1,
            id: message.id,
            ok: true,
            result,
          });
        },
      },
    },
  };
  const connection = await connectHost();
  assert.equal(connection.runtime.status, status, version);
  if (status === "native_acceptance_pending")
    assert.match(connection.runtime.notice, /稳定发行基线.*实机验收/);
  if (status === "dock_patch_required")
    assert.match(connection.runtime.notice, /0\.3\.9\.30/);
  if (status === "shared_read_required") {
    assert.match(connection.runtime.notice, /共享只读/);
    assert.equal(connection.closed, false, "missing source API still permits browsing");
    await assert.rejects(connection.artworkUrl("D:/Soundminer/cover.png"), /shared reader required/);
    assert.deepEqual(artworkReads, [], "failed preparation cannot read the original");
  }
  if (protection && shared) {
    const url = await connection.artworkUrl("D:/Soundminer/cover.png");
    assert.match(url, /^blob:/);
    URL.revokeObjectURL(url);
    assert.deepEqual(artworkReads, ["C:/PRS/native_media/cover.png", "C:/PRS/native_media/cover.png"]);
  }
  connection.close();
  assert.equal(disposed, true);
}
delete globalThis.window;
console.log(
  "Runtime handshake: old dock patch, current baseline and unknown external version passed",
);
