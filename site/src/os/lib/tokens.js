// Jylhis design tokens for JavaScript consumers (recharts, inline SVG) that
// cannot read Tailwind classes or CSS custom properties. Values mirror the
// canonical palette in src/index.css / github.com/jylhis/design. Keep in sync.

export const light = {
  bg: "#faf7f2",
  bgSubtle: "#f0ebe3",
  surface: "#e8e1d6",
  surfaceRaised: "#fefdfb",
  textHeading: "#1e1b18",
  text: "#2c2825",
  textMuted: "#6b5f54",
  textFaint: "#6d6155",
  accent: "#8a4f24",
  accentHover: "#7a4622",
  brand: "#b5703c",
  border: "#d5cec4",
  borderStrong: "#b0a898",
  decorator: "#c4baa8",
  statusOk: "#006800",
  statusWarn: "#6f5500",
  statusErr: "#a60000",
  statusInfo: "#0031a9",
};

export const dark = {
  bg: "#1a1714",
  bgSubtle: "#242019",
  surface: "#2a2520",
  surfaceRaised: "#363230",
  textHeading: "#f0eae0",
  text: "#e8e0d4",
  textMuted: "#b0a496",
  textFaint: "#8a7f72",
  accent: "#e89b5e",
  accentHover: "#f5b07a",
  brand: "#d4884a",
  border: "#3d3830",
  borderStrong: "#5a5248",
  decorator: "#4a4338",
  statusOk: "#44bc44",
  statusWarn: "#d0bc00",
  statusErr: "#ff5f59",
  statusInfo: "#2fafff",
};

// Category accents for the option dependency graph. Copper leads; the rest are
// desaturated warm-neutral siblings that read as one family (single-accent
// doctrine) rather than a rainbow.
export const categoryAccents = [
  "#8a4f24", // copper
  "#6b5f54", // muted ink
  "#6f5500", // warn ochre
  "#0031a9", // info blue
  "#7a4622", // roast copper
  "#006800", // ok green
  "#8a7f72", // faint
];

// Read the active theme from the DOM (the app sets data-mode on <html>).
export function activePalette() {
  if (typeof document !== "undefined") {
    const root = document.documentElement;
    if (root.dataset.mode === "dark") {
      return dark;
    }
  }
  return light;
}
