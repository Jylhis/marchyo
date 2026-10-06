import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  type Base16,
  type ColorsJson,
  type ThemePalette,
  batConfigWithTheme,
  consoleTable,
  detectVariant,
  fillTemplate,
  fzfOptsFor,
  gduText,
  ghosttyConfFromBase16,
  hyprlandConfFor,
  hyprlockColorsFor,
  k9sSkinText,
  lazygitText,
  matugenArgv,
  parseMatugenBase16,
  parseMatugenMaterial,
  recolorShellColors,
  resolvedPalette,
  shadeRgba,
  spotifyPlayerThemeText,
  tmThemeFromBase16,
  toCamel,
  tokenResolver,
  tty16FromBase16,
  yamlText,
} from "../src/matugen.ts";

// Nix-built parity fixture: inputs plus the output of lib/theme-generators.nix
// for them. tests/eval/theme-runtime.nix
// (eval-theme-runtime-cli-parity-fixture) fails when the Nix side drifts
// from this file and prints the JSON to paste back.
type ParityFixture = {
  batThemeName: string;
  base16: Base16;
  palette: ThemePalette;
  expected: Record<string, string> & { tokens: Record<string, string> };
};
const parity = JSON.parse(
  readFileSync(join(import.meta.dir, "fixtures", "theme-parity.json"), "utf8"),
) as ParityFixture;

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

// A small palette.json: two slotted tokens sharing a slot, one unslotted.
const palette: ThemePalette = {
  tokens: {
    bg: "#000000",
    accent: "#ffffff",
    "accent-hover": "#fefefe",
    text: "#cccccc",
    contour: "#abcdef",
  },
  tokenSlots: {
    bg: "base00",
    accent: "base09",
    "accent-hover": "base09",
    text: "base05",
  },
};

describe("tokenResolver", () => {
  const resolve = tokenResolver(
    palette,
    parseMatugenBase16(matugenFixture(), "dark"),
  );
  test("maps slotted tokens to their base16 slot", () => {
    expect(resolve("bg")).toBe("#100000");
    expect(resolve("accent")).toBe("#100009");
    expect(resolve("accent-hover")).toBe("#100009");
  });
  test("falls back to the palette hex for a token without a slot", () => {
    expect(resolve("contour")).toBe("#abcdef");
  });
  test("throws for a token the palette does not know", () => {
    expect(() => resolve("nope")).toThrow(/nope/);
  });
});

// matugen's Material `colors` block: the three roles the parser reads, plus
// one it ignores.
function materialFixture(roles: string[]): string {
  const colors: Record<string, unknown> = {};
  roles.forEach((role, i) => {
    colors[role] = {
      dark: { color: `#30000${i}` },
      light: { color: `#40000${i}` },
      default: { color: `#30000${i}` },
    };
  });
  const base = JSON.parse(matugenFixture()) as Record<string, unknown>;
  return JSON.stringify({ ...base, colors });
}

describe("parseMatugenMaterial", () => {
  const raw = materialFixture([
    "outline_variant",
    "outline",
    "primary_container",
    "scrim",
  ]);
  test("maps border, border-strong, accent-subtle for the chosen mode", () => {
    expect(parseMatugenMaterial(raw, "dark")).toEqual({
      border: "#300000",
      "border-strong": "#300001",
      "accent-subtle": "#300002",
    });
    expect(parseMatugenMaterial(raw, "light")["border-strong"]).toBe("#400001");
  });
  test("returns only the roles present (base16-only output gives none)", () => {
    expect(parseMatugenMaterial(materialFixture(["outline"]), "dark")).toEqual({
      "border-strong": "#300000",
    });
    expect(parseMatugenMaterial(matugenFixture(), "dark")).toEqual({});
  });
  test("overrides win over the base16 slot in the resolver", () => {
    const resolve = tokenResolver(
      parity.palette,
      parity.base16,
      parseMatugenMaterial(raw, "dark"),
    );
    expect(resolve("border")).toBe("#300000");
    expect(resolve("accent-subtle")).toBe("#300002");
    expect(resolve("bg")).toBe(parity.base16.base00!);
  });
});

describe("parity fixture slots", () => {
  test("selection-bg follows base02, contour keeps the Jylhis hex", () => {
    const resolve = tokenResolver(parity.palette, parity.base16);
    expect(resolve("selection-bg")).toBe(parity.base16.base02!);
    expect(resolve("contour")).toBe(parity.palette.tokens.contour!);
  });
});

describe("resolvedPalette", () => {
  test("resolves every token and keeps the slot table", () => {
    const resolve = tokenResolver(
      palette,
      parseMatugenBase16(matugenFixture(), "dark"),
    );
    const out = resolvedPalette(palette, resolve);
    expect(out.tokens).toEqual({
      accent: "#100009",
      "accent-hover": "#100009",
      bg: "#100000",
      contour: "#abcdef",
      text: "#100005",
    });
    expect(out.tokenSlots).toEqual(palette.tokenSlots);
  });
});

describe("toCamel", () => {
  test("matches lib/camel-case.nix", () => {
    expect(toCamel("bg")).toBe("bg");
    expect(toCamel("bg-subtle")).toBe("bgSubtle");
    expect(toCamel("syn-comment")).toBe("synComment");
  });
});

describe("recolorShellColors", () => {
  const resolve = tokenResolver(
    palette,
    parseMatugenBase16(matugenFixture(), "dark"),
  );
  const current: ColorsJson = {
    name: "jylhis-dark",
    variant: "dark",
    colors: {
      bg: "#000000",
      accentHover: "#fefefe",
      contour: "#abcdef",
      customUnmapped: "#123456",
    },
  };

  test("maps camelCase keys through the token resolver", () => {
    const out = recolorShellColors(current, palette, resolve, "dark", "generated");
    expect(out.colors.bg).toBe("#100000");
    expect(out.colors.accentHover).toBe("#100009");
    expect(out.colors.contour).toBe("#abcdef");
  });
  test("keeps keys that name no palette token", () => {
    const out = recolorShellColors(current, palette, resolve, "dark", "generated");
    expect(out.colors.customUnmapped).toBe("#123456");
  });
  test("sets the name and variant, keeps the key set", () => {
    const out = recolorShellColors(current, palette, resolve, "dark", "generated");
    expect(out.name).toBe("generated");
    expect(out.variant).toBe("dark");
    expect(Object.keys(out.colors).sort()).toEqual(
      Object.keys(current.colors).sort(),
    );
  });
});

describe("generators match lib/theme-generators.nix (parity fixture)", () => {
  const b = parity.base16;
  const resolve = tokenResolver(parity.palette, b);
  const exp = parity.expected;

  test("hyprlock-colors.conf", () => {
    expect(hyprlockColorsFor(resolve)).toBe(exp["hyprlock-colors.conf"]!);
  });
  test("console.txt", () => {
    expect(consoleTable(tty16FromBase16(b))).toBe(exp["console.txt"]!);
  });
  test("fzf.opts", () => {
    expect(fzfOptsFor(resolve, b.base0B!)).toBe(exp["fzf.opts"]!);
  });
  test("hyprland.conf", () => {
    expect(hyprlandConfFor(resolve)).toBe(exp["hyprland.conf"]!);
  });
  test("ghostty.conf", () => {
    expect(ghosttyConfFromBase16(b)).toBe(exp["ghostty.conf"]!);
  });
  test("bat tmTheme", () => {
    expect(tmThemeFromBase16(parity.batThemeName, b)).toBe(exp["bat.tmTheme"]!);
  });
  test("k9s-skin.yaml", () => {
    expect(k9sSkinText(b)).toBe(exp["k9s-skin.yaml"]!);
  });
  test("lazygit.yml", () => {
    expect(lazygitText(b)).toBe(exp["lazygit.yml"]!);
  });
  test("spotify-player-theme.toml", () => {
    expect(spotifyPlayerThemeText(b)).toBe(exp["spotify-player-theme.toml"]!);
  });
  test("gdu.yaml", () => {
    expect(gduText(b)).toBe(exp["gdu.yaml"]!);
  });
  test("gtk shade", () => {
    expect(shadeRgba(resolve("text"))).toBe(exp.shade!);
  });
  test("resolved palette tokens", () => {
    expect(resolvedPalette(parity.palette, resolve).tokens).toEqual(exp.tokens);
  });
});

describe("yamlText", () => {
  test("sorts keys, nests maps, quotes strings, flows lists", () => {
    expect(
      yamlText({ b: { y: ["#123456", "bold"], x: false }, a: "default" }),
    ).toBe('a: "default"\nb:\n  x: false\n  y: ["#123456", "bold"]\n');
  });
});

describe("fillTemplate", () => {
  const resolve = tokenResolver(parity.palette, parity.base16);
  test("fills token placeholders and the shade", () => {
    const out = fillTemplate(
      "a {{token:bg}} b {{token:contour}} c {{shade}} {{token:bg}}",
      resolve,
    );
    expect(out).toBe(
      `a ${parity.base16.base00} b ${parity.palette.tokens.contour} ` +
        `c ${parity.expected.shade} ${parity.base16.base00}`,
    );
    expect(out).not.toContain("{{");
  });
  test("an unknown token throws instead of shipping a placeholder", () => {
    expect(() => fillTemplate("{{token:nope}}", resolve)).toThrow(/nope/);
  });
});

describe("batConfigWithTheme", () => {
  test("rewrites only the --theme= line", () => {
    const conf = '--map-syntax="*.nix:Nix"\n--theme=jylhis-dark\n--style=plain\n';
    expect(batConfigWithTheme(conf, "marchyo-generated")).toBe(
      '--map-syntax="*.nix:Nix"\n--theme=marchyo-generated\n--style=plain\n',
    );
  });
});

describe("hyprlandConfFor", () => {
  test("emits the three color keywords in the parsed line form (no #)", () => {
    const b = parseMatugenBase16(matugenFixture(), "dark");
    expect(hyprlandConfFor(tokenResolver(parity.palette, b))).toBe(
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

describe("fzfOptsFor", () => {
  const b = parseMatugenBase16(matugenFixture(), "dark");
  const opts = fzfOptsFor(tokenResolver(parity.palette, b), b.base0B!);

  test("emits a single --color line with trailing newline", () => {
    expect(opts.startsWith("--color=")).toBe(true);
    expect(opts.endsWith("\n")).toBe(true);
    expect(opts.trim().split("\n")).toHaveLength(1);
  });
  test("maps roles through the palette.json slot table", () => {
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
