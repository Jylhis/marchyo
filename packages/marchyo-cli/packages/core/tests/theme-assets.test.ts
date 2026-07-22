import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  THEME_ALIASES,
  type ThemeManifestEntry,
  nextTheme,
  pointCurrentTheme,
  readThemeManifest,
  themeAtPointer,
  themeManifestPath,
} from "../src/theme-assets.ts";

function fixture(): {
  dir: string;
  manifestPath: string;
  entries: ThemeManifestEntry[];
} {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-theme-assets-"));
  const entries: ThemeManifestEntry[] = [];
  for (const [name, variant] of [
    ["alpha", "dark"],
    ["beta", "light"],
  ] as const) {
    const themeDir = join(dir, "themes", name);
    mkdirSync(themeDir, { recursive: true });
    entries.push({ name, variant, dir: themeDir });
  }
  const manifestPath = join(dir, "manifest.json");
  writeFileSync(manifestPath, JSON.stringify(entries));
  return { dir, manifestPath, entries };
}

describe("themeManifestPath", () => {
  test("honors XDG_DATA_HOME", () => {
    expect(themeManifestPath({ XDG_DATA_HOME: "/xdg/data" })).toBe(
      "/xdg/data/marchyo/themes/manifest.json",
    );
  });
});

describe("readThemeManifest", () => {
  test("missing file yields []", async () => {
    expect(await readThemeManifest("/nonexistent/manifest.json")).toEqual([]);
  });

  test("invalid content warns and yields []", async () => {
    const { dir, manifestPath } = fixture();
    try {
      writeFileSync(manifestPath, "{nope");
      const warnings: string[] = [];
      expect(
        await readThemeManifest(manifestPath, (m) => warnings.push(m)),
      ).toEqual([]);
      expect(warnings.length).toBe(1);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("round-trips valid entries", async () => {
    const { dir, manifestPath, entries } = fixture();
    try {
      expect(await readThemeManifest(manifestPath)).toEqual(entries);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("pointer", () => {
  test("pointCurrentTheme + themeAtPointer round-trip and re-point", async () => {
    const { dir, entries } = fixture();
    try {
      const pointer = join(dir, "config", "marchyo", "current-theme");
      expect(themeAtPointer(entries, pointer)).toBeNull();
      await pointCurrentTheme(entries[0]!.dir, pointer);
      expect(themeAtPointer(entries, pointer)?.name).toBe("alpha");
      await pointCurrentTheme(entries[1]!.dir, pointer);
      expect(themeAtPointer(entries, pointer)?.name).toBe("beta");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("nextTheme", () => {
  const list: ThemeManifestEntry[] = [
    { name: "a", variant: "dark", dir: "/a" },
    { name: "b", variant: "light", dir: "/b" },
  ];

  test("cycles and wraps", () => {
    expect(nextTheme(list, list[0]!)?.name).toBe("b");
    expect(nextTheme(list, list[1]!)?.name).toBe("a");
  });

  test("null/unknown current starts at the first entry", () => {
    expect(nextTheme(list, null)?.name).toBe("a");
    expect(
      nextTheme(list, { name: "zz", variant: "dark", dir: "/zz" })?.name,
    ).toBe("a");
  });

  test("empty manifest yields null", () => {
    expect(nextTheme([], null)).toBeNull();
  });
});

describe("aliases", () => {
  test("dark/light map to the Jylhis pair", () => {
    expect(THEME_ALIASES.dark).toBe("jylhis-dark");
    expect(THEME_ALIASES.light).toBe("jylhis-light");
  });
});
