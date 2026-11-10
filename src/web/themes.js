// Color seeds from Codex 26.1103.7773.0; see docs/CODEX_THEME_PALETTES.md.
// Only palette data is shared. PRS derives its own surface hierarchy.
export const themeVariants = [
  ["absolutely", "Absolutely", "dark", "#2d2d2b", "#f9f9f7", "#cc7d5e"],
  ["absolutely", "Absolutely", "light", "#f9f9f7", "#2d2d2b", "#cc7d5e"],
  ["ayu", "Ayu", "dark", "#10141c", "#bfbdb6", "#e6b450"],
  ["catppuccin", "Catppuccin", "dark", "#1e1e2e", "#cdd6f4", "#cba6f7"],
  ["catppuccin", "Catppuccin", "light", "#eff1f5", "#4c4f69", "#8839ef"],
  ["codex", "Codex", "dark", "#111111", "#fcfcfc", "#0169cc"],
  ["codex", "Codex", "light", "#ffffff", "#0d0d0d", "#0169cc"],
  ["dracula", "Dracula", "dark", "#282a36", "#f8f8f2", "#ff79c6"],
  ["everforest", "Everforest", "dark", "#2d353b", "#d3c6aa", "#a7c080"],
  ["everforest", "Everforest", "light", "#fdf6e3", "#5c6a72", "#93b259"],
  ["github", "GitHub", "dark", "#0d1117", "#e6edf3", "#1f6feb"],
  ["github", "GitHub", "light", "#ffffff", "#1f2328", "#0969da"],
  ["gruvbox", "Gruvbox", "dark", "#282828", "#ebdbb2", "#458588"],
  ["gruvbox", "Gruvbox", "light", "#fbf1c7", "#3c3836", "#458588"],
  ["linear", "Linear", "dark", "#0f0f11", "#e3e4e6", "#606acc"],
  ["linear", "Linear", "light", "#fcfcfd", "#1b1b1b", "#5e6ad2"],
  ["lobster", "Lobster", "dark", "#111827", "#e4e4e7", "#ff5c5c"],
  ["material", "Material", "dark", "#212121", "#eeffff", "#80cbc4"],
  ["matrix", "Matrix", "dark", "#040805", "#b8ffca", "#1eff5a"],
  ["monokai", "Monokai", "dark", "#272822", "#f8f8f2", "#99947c"],
  ["night-owl", "Night Owl", "dark", "#011627", "#d6deeb", "#44596b"],
  ["nord", "Nord", "dark", "#2e3440", "#d8dee9", "#88c0d0"],
  ["notion", "Notion", "dark", "#191919", "#d9d9d8", "#3183d8"],
  ["notion", "Notion", "light", "#ffffff", "#37352f", "#3183d8"],
  ["og", "OG", "dark", "#343541", "#d1d5db", "#10a37f"],
  ["one", "One", "dark", "#282c34", "#abb2bf", "#4d78cc"],
  ["one", "One", "light", "#fafafa", "#383a42", "#526fff"],
  ["oscurange", "Oscurange", "dark", "#0b0b0f", "#e6e6e6", "#f9b98c"],
  ["proof", "Proof", "light", "#f5f3ed", "#2f312d", "#3d755d"],
  ["raycast", "Raycast", "dark", "#101010", "#fefefe", "#ff6363"],
  ["raycast", "Raycast", "light", "#ffffff", "#030303", "#ff6363"],
  ["rose-pine", "Rose Pine", "dark", "#232136", "#e0def4", "#ea9a97"],
  ["rose-pine", "Rose Pine", "light", "#faf4ed", "#575279", "#d7827e"],
  ["sentry", "Sentry", "dark", "#2d2935", "#e6dff9", "#7055f6"],
  ["solarized", "Solarized", "dark", "#002b36", "#839496", "#d30102"],
  ["solarized", "Solarized", "light", "#fdf6e3", "#657b83", "#b58900"],
  ["temple", "Temple", "dark", "#02120c", "#c7e6da", "#e4f222"],
  ["tokyo-night", "Tokyo Night", "dark", "#1a1b26", "#a9b1d6", "#3d59a1"],
  ["vercel", "Vercel", "dark", "#000000", "#ededed", "#006efe"],
  ["vercel", "Vercel", "light", "#ffffff", "#171717", "#006aff"],
  ["vscode-plus", "VS Code Plus", "dark", "#1e1e1e", "#d4d4d4", "#007acc"],
  ["vscode-plus", "VS Code Plus", "light", "#ffffff", "#000000", "#007acc"],
  ["xcode", "Xcode", "dark", "#1f1f24", "#ffffff", "#5482ff"],
  ["xcode", "Xcode", "light", "#ffffff", "#000000", "#0e0eff"],
].map(([id, label, tone, background, foreground, accent]) => ({
  id,
  label,
  tone,
  background,
  foreground,
  accent,
}));

export const themePresets = [...new Set(themeVariants.map(({ id }) => id))].map(
  (id) => ({
    id,
    label: themeVariants.find((theme) => theme.id === id).label,
    variants: themeVariants.filter((theme) => theme.id === id),
  }),
);

export function resolveTheme(
  id,
  mode = "dark",
  systemDark = matchMedia("(prefers-color-scheme: dark)").matches,
) {
  const theme =
    themePresets.find((item) => item.id === id) ||
    themePresets.find((item) => item.id === "github");
  const tone = mode === "system" ? (systemDark ? "dark" : "light") : mode;
  return theme.variants.find((item) => item.tone === tone) || theme.variants[0];
}

const validColor = (color) => /^#[\da-f]{6}$/i.test(color || "");
const rgb = (color) =>
  color
    .slice(1)
    .match(/../g)
    .map((part) => parseInt(part, 16));
function mix(a, b, amount) {
  const target = rgb(b);
  return (
    "#" +
    rgb(a)
      .map((part, i) =>
        Math.round(part + (target[i] - part) * amount)
          .toString(16)
          .padStart(2, "0"),
      )
      .join("")
  );
}
function luminance(color) {
  return rgb(color)
    .map((value) => {
      value /= 255;
      return value <= 0.04045
        ? value / 12.92
        : ((value + 0.055) / 1.055) ** 2.4;
    })
    .reduce(
      (sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index],
      0,
    );
}

export function themeColors(theme, overrides = {}) {
  const bg = validColor(overrides.backgroundColor)
    ? overrides.backgroundColor
    : theme.background;
  const text = validColor(overrides.foregroundColor)
    ? overrides.foregroundColor
    : theme.foreground;
  const accent = validColor(overrides.accentColor)
    ? overrides.accentColor
    : theme.accent;
  const surface = validColor(overrides.surfaceColor)
    ? overrides.surfaceColor
    : mix(bg, text, 0.035);
  // Accent fills retain the exact seed. Text on them chooses a readable contrast.
  const light = luminance(accent);
  const onAccent =
    (light + 0.05) / 0.05 > 1.05 / (light + 0.05) ? "#000000" : "#ffffff";
  return {
    bg,
    text,
    accent,
    surface,
    raised: mix(bg, text, 0.075),
    muted: mix(bg, text, 0.68),
    line: mix(bg, text, 0.16),
    quiet: mix(bg, text, 0.055),
    selected: mix(bg, accent, 0.24),
    heading: mix(surface, accent, 0.035),
    input: bg,
    "on-accent": onAccent,
  };
}

export function selectTheme(
  preferences,
  id,
  mode = preferences.themeMode || "dark",
) {
  const theme = resolveTheme(id, mode);
  Object.assign(preferences, {
    theme: theme.id,
    themeMode: mode,
    themeTone: theme.tone,
    themeColorsVersion: 3,
    accentColor: theme.accent,
    backgroundColor: theme.background,
    foregroundColor: theme.foreground,
    surfaceColor: themeColors(theme).surface,
  });
}

export function syncSystemTheme(preferences) {
  const theme = resolveTheme(preferences.theme, preferences.themeMode);
  if (
    preferences.themeMode !== "system" ||
    preferences.themeTone === theme.tone
  )
    return;
  const previous = resolveTheme(
    preferences.theme,
    preferences.themeTone || theme.tone,
  );
  const overrides = {};
  for (const [key, value] of Object.entries({
    backgroundColor: previous.background,
    foregroundColor: previous.foreground,
    accentColor: previous.accent,
    surfaceColor: themeColors(previous).surface,
  }))
    if (preferences[key] !== value) overrides[key] = preferences[key];
  selectTheme(preferences, preferences.theme, "system");
  Object.assign(preferences, overrides);
}

export function migrateTheme(preferences) {
  if (preferences.themeColorsVersion === 3) return;
  const legacy = {
    graphite: ["github", "dark", "#8aafff", "#202329", "#1e2530"],
    dark: ["codex", "dark", "#c7b57f", "#222426", "#252628"],
    slate: ["ayu", "dark", "#6ad4ce", "#192b38", "#1b2a30"],
    amethyst: ["catppuccin", "dark", "#c2a3f7", "#272333", "#292532"],
    forest: ["everforest", "dark", "#9dcbb2", "#202e28", "#252d27"],
    paper: ["everforest", "light", "#3d6b64", "#e4e4de", "#d0d0c8"],
    frost: ["github", "light", "#345d9d", "#e8edf5", "#ccd5e0"],
  }[preferences.theme];
  const saved = { ...preferences };
  selectTheme(
    preferences,
    legacy?.[0] || preferences.theme,
    legacy?.[1] || preferences.themeMode || "dark",
  );
  // Preserve deliberate custom colors; old preset defaults adopt the new seeds.
  if (legacy) {
    if (
      validColor(saved.accentColor) &&
      saved.accentColor !== legacy[2] &&
      !(saved.themeColorsVersion === 0 && saved.accentColor === "#c7b57f")
    )
      preferences.accentColor = saved.accentColor;
    if (
      validColor(saved.surfaceColor) &&
      !legacy.slice(3).includes(saved.surfaceColor) &&
      !(saved.themeColorsVersion === 0 && saved.surfaceColor === "#222426")
    )
      preferences.surfaceColor = saved.surfaceColor;
  }
}
