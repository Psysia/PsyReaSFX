import english from "./translations.en.js";

// Only presentation text is localized; catalog content and editable values stay literal.
const literal =
  '.result-row,.selected-name,.path-label,#asset-name,#asset-info,#tabs,.technical dd,#collections,#saved-searches,#ucs-categories,#search-suggestions [role="option"],[data-literal],.scope-control option:not([value=""])';
export function createLocalizer() {
  let language = "zh";
  const textRecords = new WeakMap();
  const attributeRecords = new WeakMap();
  const attributes = ["title", "aria-label", "placeholder"];
  const options = {
    subtree: true,
    childList: true,
    characterData: true,
    attributes: true,
    attributeFilter: attributes,
  };
  function translate(source) {
    if (language !== "en") return source;
    const trimmed = source.trim();
    let result = english[trimmed];
    if (!result) {
      result = trimmed
        .replace(
          /^([\d,]+) 个结果( · 更新中)?$/,
          (_, count, pending) =>
            `${count} results${pending ? " · Updating" : ""}`,
        )
        .replace(/^编辑 (\d+) 个素材$/, "Edit $1 assets")
        .replace(
          /^状态 · (.+)$/,
          (_, value) => `Status · ${english[value] || value}`,
        )
        .replace(/^确认 UCS · /, "Confirm UCS · ")
        .replace(
          /^应用 (.+)$/,
          (_, value) => `Apply ${english[value] || value}`,
        )
        .replace(/^↑ (.+)$/, (_, value) => `↑ ${english[value] || value}`)
        .replace(/^全部 (.+)$/, "All $1");
      result = result.replace(
        /^停止 · (.+)$/,
        (_, value) => `Stop · ${english[value] || value}`,
      );
    }
    return source.replace(trimmed, result);
  }
  function text(item) {
    const parent = item.parentElement;
    if (!parent || parent.closest(`${literal},script,style,textarea`)) return;
    const old = textRecords.get(item);
    const source = old?.rendered === item.data ? old.source : item.data;
    const rendered = translate(source);
    textRecords.set(item, { source, rendered });
    if (item.data !== rendered) item.data = rendered;
  }
  function element(item) {
    if (item.closest(literal)) return;
    const records = attributeRecords.get(item) || {};
    for (const attribute of attributes) {
      if (!item.hasAttribute(attribute)) continue;
      const value = item.getAttribute(attribute);
      const old = records[attribute];
      const source = old?.rendered === value ? old.source : value;
      const rendered = translate(source);
      records[attribute] = { source, rendered };
      if (value !== rendered) item.setAttribute(attribute, rendered);
    }
    attributeRecords.set(item, records);
  }
  function visit(root) {
    if (root.nodeType === Node.TEXT_NODE) {
      text(root);
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE) return;
    element(root);
    const walker = document.createTreeWalker(
      root,
      NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT,
    );
    while (walker.nextNode()) {
      if (walker.currentNode.nodeType === Node.TEXT_NODE)
        text(walker.currentNode);
      else element(walker.currentNode);
    }
  }
  const observer = new MutationObserver((mutations) => {
    observer.disconnect();
    for (const mutation of mutations) {
      if (mutation.type === "childList")
        for (const child of mutation.addedNodes) visit(child);
      else visit(mutation.target);
    }
    if (language === "en") observer.observe(document.body, options);
  });
  return {
    setLanguage(value) {
      const next = value === "en" ? "en" : "zh";
      if (next === language) return;
      language = next;
      observer.disconnect();
      visit(document.body);
      document.documentElement.lang = language === "en" ? "en-US" : "zh-CN";
      if (language === "en") observer.observe(document.body, options);
    },
    close() {
      observer.disconnect();
    },
  };
}
