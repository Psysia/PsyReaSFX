// Small, consistent line icons; no fonts or network resources are required.
const paths = {
  folder: "M3 6h6l2 2h10v12H3z M3 10h18",
  folderOpen: "M3 19V6h6l2 2h9v3 M3 19l3-8h16l-3 8z",
  list: "M8 6h13 M8 12h13 M8 18h13 M3 6h1 M3 12h1 M3 18h1",
  star: "m12 3 3 6 6.5 1-4.7 4.5 1.1 6.5-5.9-3.1L6.1 21l1.1-6.5L2.5 10 6 9z",
  clock: "M12 8v5l3 2 M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0",
  layers: "m3 7 9-4 9 4-9 4z M3 12l9 4 9-4 M3 17l9 4 9-4",
  tag: "M3 3h8l10 10-8 8L3 11z M7 7h.01",
  settings: "M4 7h16 M4 17h16 M8 4v6 M16 14v6",
  columns: "M3 4h18v16H3z M9 4v16 M15 4v16",
  panel: "M3 4h18v16H3z M15 4v16",
  menu: "M4 6h16 M4 12h16 M4 18h16",
};
export function icon(name) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("class", "ui-icon");
  const path = document.createElementNS(svg.namespaceURI, "path");
  path.setAttribute("d", paths[name] || paths.list);
  svg.append(path);
  return svg;
}
