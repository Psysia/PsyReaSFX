// One asynchronous protocol is shared by the ReaWebAPI and WebView2 transports.
export class HostConnection extends EventTarget {
  constructor(send) {
    super();
    this.send = send;
    this.pending = new Map();
    this.prefix = Array.from(
      crypto.getRandomValues(new Uint32Array(3)),
      (value) => value.toString(16),
    ).join("-");
    this.sequence = 0;
    this.state = null;
    this.session = null;
    this.closed = false;
  }

  receive(raw) {
    let message;
    try {
      message = typeof raw === "string" ? JSON.parse(raw) : raw;
    } catch {
      return;
    }
    if (!message || message.protocol !== 1) return;
    if (message.event === "state") {
      this.state = message.data;
      this.dispatchEvent(new CustomEvent("state", { detail: message.data }));
      return;
    }
    const request = this.pending.get(message.id);
    if (!request) return;
    clearTimeout(request.timer);
    this.pending.delete(message.id);
    if (message.ok) request.resolve(message.result);
    else request.reject(new Error(message.error || "宿主操作失败"));
  }

  request(method, params = {}) {
    if (this.closed) return Promise.reject(new Error("宿主连接已关闭"));
    if (this.pending.size >= 32)
      return Promise.reject(new Error("操作正在排队，请稍后重试"));
    const id = `${this.prefix}-${++this.sequence}`;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => {
          this.pending.delete(id);
          reject(new Error("宿主响应超时，请检查 REAPER 是否正在处理模态窗口"));
        },
        [
          "path.choose",
          "library.add",
          "library.drop",
          "management.action",
          "transfer.directory",
          "records.action",
          "asset.action",
        ].includes(method)
          ? 300000
          : 25000,
      );
      this.pending.set(id, { resolve, reject, timer });
      Promise.resolve()
        .then(() =>
          // Native ReaWebAPI rejects undefined properties, including optional fields.
          this.send(
            JSON.parse(JSON.stringify({ protocol: 1, id, method, params })),
          ),
        )
        .catch((error) => {
          clearTimeout(timer);
          this.pending.delete(id);
          reject(error);
        });
    });
  }

  close() {
    this.closed = true;
    for (const request of this.pending.values()) {
      clearTimeout(request.timer);
      request.reject(new Error("窗口已关闭"));
    }
    this.pending.clear();
    this.dispose?.();
  }
}

function inspectRuntime(native, policy) {
  if (
    !policy ||
    native?.protocol !== policy.protocol ||
    !policy.runtime_contracts?.includes(native?.runtime?.contract) ||
    !policy.web_contracts?.includes(native?.webRuntime?.contract) ||
    !(native?.runtime?.host?.maxMessageBytes >= policy.minimum_message_bytes)
  ) {
    throw new Error(
      "ReaWebAPI 接口契约不兼容。请关闭 REAPER，使用安装器的 -UseBundledRuntime 选项恢复随包版本，再重启。",
    );
  }
  const version = typeof native.version === "string" ? native.version : "未知";
  const baseline = policy.baseline_versions?.includes(version);
  return {
    version,
    status: baseline ? policy.validation_status : "external_unverified",
    notice: baseline
      ? policy.validation_status === "native_acceptance_pending"
        ? "随包候选版本 · 待 REAPER 实机验收"
        : "随包基线版本"
      : "外部版本 · 接口检查通过，尚未完成本应用回归验证",
  };
}

export async function connectHost() {
  let connection;
  let native;
  if (window.reaper?.lifecycle?.ready) {
    native = await window.reaper.lifecycle.ready;
    if (native?.protocol !== 1) {
      throw new Error("ReaWebAPI 协议版本不兼容，请恢复随包运行时版本。");
    }
    if (
      typeof window.reaper.host?.send !== "function" ||
      typeof window.reaper.events?.on !== "function"
    ) {
      throw new Error("ReaWebAPI 缺少消息通道，请使用完整安装包恢复随包版本。");
    }
    connection = new HostConnection((message) =>
      window.reaper.host.send(message),
    );
    connection.dispose = await window.reaper.events.on("message", (raw) =>
      connection.receive(raw),
    );
    // A reused/native window may retain routing from its previous document.
    // Configure the window itself; app.json and DOM preventDefault alone do
    // not disable the runtime's document-start Main/Space forwarding handlers.
    try {
      const keyboard = window.reaper.window;
      for (const [method, value] of [
        ["setDawKeyboard", false],
        ["setShortcutRouting", false],
        ["setKeyboardCapture", true],
      ]) {
        if (typeof keyboard?.[method] !== "function")
          throw new Error(
            "当前 ReaWebAPI 缺少窗口键盘控制，请更新随包运行时。",
          );
        await keyboard[method](value);
      }
      connection.keyboardState = () => keyboard.getState();
      const state = await connection.keyboardState();
      if (
        state.dawKeyboard !== false ||
        state.shortcutRouting !== false ||
        state.keyboardCapture !== true
      )
        throw new Error(
          "窗口未能启用本地试听键盘控制，请关闭此窗口后重新打开。",
        );
    } catch (error) {
      connection.close();
      throw error;
    }
    connection.subscribeDrops = async (callback) => {
      const dispose = await window.reaper.events.on("native-drop", callback);
      if (connection.closed) {
        dispose();
        return;
      }
      const previousDispose = connection.dispose;
      connection.dispose = () => {
        previousDispose?.();
        dispose();
      };
    };
    connection.dragFiles = (paths) => {
      if (!window.reaper.dragDrop?.startFiles)
        return Promise.reject(
          new Error("当前 ReaWebAPI 未提供原生文件拖放，请更新扩展。"),
        );
      return window.reaper.dragDrop.startFiles(paths);
    };
    connection.reveal = (path) => {
      if (!window.reaper.system?.revealInFileManager)
        return Promise.reject(new Error("当前扩展不支持打开文件位置"));
      return window.reaper.system.revealInFileManager(path);
    };
    connection.artworkUrl = async (path) => {
      if (!window.reaper.fs?.stat || !window.reaper.fs?.readFile) return null;
      const info = await window.reaper.fs.stat(path);
      if (!info.exists || !info.size || info.size > 2 * 1024 * 1024)
        return null;
      const bytes = await window.reaper.fs.readFile(path, {
        encoding: "binary",
      });
      const extension = path.split(".").pop().toLowerCase();
      const mime = {
        png: "image/png",
        jpg: "image/jpeg",
        jpeg: "image/jpeg",
        webp: "image/webp",
        gif: "image/gif",
        bmp: "image/bmp",
      }[extension];
      if (!mime) return null;
      return URL.createObjectURL(new Blob([bytes], { type: mime }));
    };
  } else if (window.chrome?.webview) {
    const webview = window.chrome.webview;
    connection = new HostConnection((message) => webview.postMessage(message));
    const receive = (event) => connection.receive(event.data);
    webview.addEventListener("message", receive);
    connection.dispose = () => webview.removeEventListener("message", receive);
    connection.dragFiles = (paths) =>
      connection.request("drag.files", { paths });
    connection.reveal = (path) => connection.request("system.reveal", { path });
    connection.artworkUrl = (path) =>
      connection.request("artwork.url", { path });
  } else {
    throw new Error(
      "请在 REAPER 动作列表中运行打包后的 PsyReaSFX.lua，或通过 Windows Desktop 宿主打开此界面。",
    );
  }
  try {
    connection.session = await connection.request("session.ready");
    if (connection.session.protocol !== 1) {
      throw new Error("宿主协议版本不匹配，请重新构建前端与 Lua 后端。");
    }
    if (native)
      connection.runtime = inspectRuntime(
        native,
        connection.session.runtimePolicy,
      );
    return connection;
  } catch (error) {
    connection.close();
    throw error;
  }
}
