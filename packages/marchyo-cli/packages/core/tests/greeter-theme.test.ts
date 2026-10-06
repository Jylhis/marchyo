import { afterEach, describe, expect, test } from "bun:test";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  GREETER_THEME_DIR,
  greeterThemeDir,
  writeGreeterTheme,
} from "../src/greeter-theme.ts";

const roots: string[] = [];

function fixture(colors: unknown): { themeDir: string; markerDir: string } {
  const root = mkdtempSync(join(tmpdir(), "marchyo-greeter-theme-"));
  roots.push(root);
  const themeDir = join(root, "theme");
  const markerDir = join(root, "greeter");
  mkdirSync(themeDir);
  mkdirSync(markerDir);
  if (colors !== undefined) {
    writeFileSync(join(themeDir, "colors.json"), JSON.stringify(colors));
  }
  return { themeDir, markerDir };
}

afterEach(() => {
  for (const r of roots.splice(0)) {
    chmodSync(join(r, "greeter"), 0o755);
    rmSync(r, { recursive: true, force: true });
  }
});

describe("greeterThemeDir", () => {
  test("defaults to the path modules/nixos/boot.nix creates", () => {
    expect(greeterThemeDir({})).toBe("/var/lib/marchyo/greeter");
    expect(GREETER_THEME_DIR).toBe("/var/lib/marchyo/greeter");
  });

  test("honors MARCHYO_GREETER_THEME_DIR", () => {
    expect(greeterThemeDir({ MARCHYO_GREETER_THEME_DIR: "/x/y" })).toBe(
      "/x/y",
    );
  });
});

describe("writeGreeterTheme", () => {
  test("writes name, variant and #rrggbb colours, world-readable", async () => {
    const { themeDir, markerDir } = fixture({
      name: "nord",
      variant: "light",
      colors: { bg: "#ECEFF4", accent: "#5e81ac", bogus: "rgb(1,2,3)" },
    });
    expect(await writeGreeterTheme(themeDir, markerDir)).toBe(true);
    const marker = join(markerDir, "theme.json");
    expect(JSON.parse(readFileSync(marker, "utf8"))).toEqual({
      name: "nord",
      variant: "light",
      colors: { bg: "#ECEFF4", accent: "#5e81ac" },
    });
    expect(statSync(marker).mode & 0o777).toBe(0o644);
    // Atomic replace: no temp file left behind.
    expect(readdirSync(markerDir)).toEqual(["theme.json"]);
  });

  test("replaces an existing marker", async () => {
    const { themeDir, markerDir } = fixture({
      name: "jylhis-dark",
      variant: "dark",
      colors: { bg: "#0c0f14" },
    });
    writeFileSync(join(markerDir, "theme.json"), "stale");
    expect(await writeGreeterTheme(themeDir, markerDir)).toBe(true);
    expect(
      JSON.parse(readFileSync(join(markerDir, "theme.json"), "utf8")).name,
    ).toBe("jylhis-dark");
  });

  test("skips when the marker dir is absent", async () => {
    const { themeDir, markerDir } = fixture({
      name: "a",
      variant: "dark",
      colors: {},
    });
    expect(await writeGreeterTheme(themeDir, join(markerDir, "nope"))).toBe(
      false,
    );
  });

  test("skips when the marker dir is not writable", async () => {
    const { themeDir, markerDir } = fixture({
      name: "a",
      variant: "dark",
      colors: {},
    });
    chmodSync(markerDir, 0o555);
    // Root bypasses the mode bits; the assertion only holds for a normal user.
    if (process.getuid?.() !== 0) {
      expect(await writeGreeterTheme(themeDir, markerDir)).toBe(false);
    }
    chmodSync(markerDir, 0o755);
    expect(readdirSync(markerDir)).toEqual([]);
  });

  test("skips a missing or invalid colors.json", async () => {
    const missing = fixture(undefined);
    expect(await writeGreeterTheme(missing.themeDir, missing.markerDir)).toBe(
      false,
    );
    const invalid = fixture({ name: "a", variant: "sepia", colors: {} });
    expect(await writeGreeterTheme(invalid.themeDir, invalid.markerDir)).toBe(
      false,
    );
    expect(readdirSync(invalid.markerDir)).toEqual([]);
  });
});
