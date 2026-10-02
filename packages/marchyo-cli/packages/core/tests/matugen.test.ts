import { describe, expect, test } from "bun:test";
import {
  type ColorsJson,
  detectVariant,
  fzfOptsFromBase16,
  ghosttyConfFromBase16,
  hyprlandConfFromBase16,
  matugenArgv,
  parseMatugenBase16,
  recolorShellColors,
} from "../src/matugen.ts";

// A matugen-shaped `--json hex` fixture: only the fields the parser reads,
// with distinguishable dark/light values per slot.
function matugenFixture(): string {
  const slots = [
    "base00",
    "base01",
    "base02",
    "base03",
    "base04",
    "base05",
    "base06",
    "base07",
    "base08",
    "base09",
    "base0A",
    "base0B",
    "base0C",
    "base0D",
    "base0E",
    "base0F",
  ];
  const base16: Record<string, unknown> = {};
  slots.forEach((slot, i) => {
    const d = `#${(0x100000 + i).toString(16).padStart(6, "0")}`;
    const l = `#${(0x200000 + i).toString(16).padStart(6, "0")}`;
    base16[slot] = {
      dark: { color: d.toUpperCase() },
      light: { color: l.toUpperCase() },
      default: { color: d.toUpperCase() },
    };
  });
  return JSON.stringify({ is_dark_mode: true, base16 });
}

describe("matugenArgv", () => {
  test("runs image mode with json hex and a fixed source index (headless)", () => {
    expect(matugenArgv("/x/wall.png")).toEqual([
      "matugen",
      "image",
      "/x/wall.png",
      "--json",
      "hex",
      "--source-color-index",
      "0",
    ]);
  });
});

describe("detectVariant", () => {
  test("is_dark_mode true -> dark", () => {
    expect(detectVariant(matugenFixture())).toBe("dark");
  });
  test("is_dark_mode false -> light", () => {
    expect(
      detectVariant(JSON.stringify({ is_dark_mode: false, base16: {} })),
    ).toBe("light");
  });
});

describe("parseMatugenBase16", () => {
  test("picks the dark color per slot and lowercases", () => {
    const b = parseMatugenBase16(matugenFixture(), "dark");
    expect(b.base00).toBe("#100000");
    expect(b.base09).toBe("#100009");
    expect(b.base0F).toBe("#10000f");
  });
  test("picks the light color when variant is light", () => {
    const b = parseMatugenBase16(matugenFixture(), "light");
    expect(b.base00).toBe("#200000");
    expect(b.base05).toBe("#200005");
  });
  test("throws when a slot is missing", () => {
    expect(() =>
      parseMatugenBase16(JSON.stringify({ base16: {} }), "dark"),
    ).toThrow(/missing base00/);
  });
});

describe("recolorShellColors", () => {
  const base16 = parseMatugenBase16(matugenFixture(), "dark");
  const current: ColorsJson = {
    name: "jylhis-dark",
    variant: "dark",
    colors: {
      bg: "#000000", // -> base00
      accent: "#ffffff", // -> base09
      text: "#cccccc", // -> base05
      customUnmapped: "#abcdef", // no slot -> kept as-is
    },
  };

  test("maps known tokens to their base16 slot", () => {
    const out = recolorShellColors(current, base16, "dark", "generated");
    expect(out.colors.bg).toBe("#100000");
    expect(out.colors.accent).toBe("#100009");
    expect(out.colors.text).toBe("#100005");
  });
  test("keeps unmapped keys at their current hex (identity fallback)", () => {
    const out = recolorShellColors(current, base16, "dark", "generated");
    expect(out.colors.customUnmapped).toBe("#abcdef");
  });
  test("sets the name and variant, keeps the key set", () => {
    const out = recolorShellColors(current, base16, "dark", "generated");
    expect(out.name).toBe("generated");
    expect(out.variant).toBe("dark");
    expect(Object.keys(out.colors).sort()).toEqual(
      Object.keys(current.colors).sort(),
    );
  });
});

describe("hyprlandConfFromBase16", () => {
  test("emits the three color keywords in the parsed line form (no #)", () => {
    const b = parseMatugenBase16(matugenFixture(), "dark");
    expect(hyprlandConfFromBase16(b)).toBe(
      [
        "misc:background_color rgb(100000)",
        "general:col.active_border rgba(100009ff)",
        "general:col.inactive_border rgba(100004ff)",
        "",
      ].join("\n"),
    );
  });
});

describe("ghosttyConfFromBase16", () => {
  const b = parseMatugenBase16(matugenFixture(), "dark");
  const conf = ghosttyConfFromBase16(b);

  test("sets background/foreground/cursor/selection from the palette", () => {
    expect(conf).toContain("background = #100000");
    expect(conf).toContain("foreground = #100005");
    expect(conf).toContain("cursor-color = #100005");
    expect(conf).toContain("selection-background = #100002");
  });
  test("emits 16 palette entries with the base16 ANSI mapping", () => {
    const lines = conf.trim().split("\n");
    const palette = lines.filter((l) => l.startsWith("palette = "));
    expect(palette).toHaveLength(16);
    expect(palette[0]).toBe("palette = 0=#100000"); // base00
    expect(palette[1]).toBe("palette = 1=#100008"); // base08
    expect(palette[15]).toBe("palette = 15=#100007"); // base07
  });
});

describe("fzfOptsFromBase16", () => {
  const b = parseMatugenBase16(matugenFixture(), "dark");
  const opts = fzfOptsFromBase16(b);

  test("emits a single --color line with trailing newline", () => {
    expect(opts.startsWith("--color=")).toBe(true);
    expect(opts.endsWith("\n")).toBe(true);
    expect(opts.trim().split("\n")).toHaveLength(1);
  });
  test("maps roles through the same slot mapping as theme-runtime.nix", () => {
    expect(opts).toContain("fg:#100005"); // text -> base05
    expect(opts).toContain("bg:#100000"); // bg -> base00
    expect(opts).toContain("hl:#100009"); // accent -> base09
    expect(opts).toContain("fg+:#100006"); // text-heading -> base06
    expect(opts).toContain("bg+:#100001"); // accent-subtle -> base01
    expect(opts).toContain("marker:#10000b"); // green -> base0B
    expect(opts).toContain("border:#100003"); // border -> base03
    expect(opts).toContain("gutter:#100000"); // bg -> base00
  });
});
