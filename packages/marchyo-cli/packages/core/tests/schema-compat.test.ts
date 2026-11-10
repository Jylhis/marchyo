// Parse-behaviour fixtures for the persisted formats validated with zod.
// They were written against zod 3 and must keep passing on zod 4: any drift
// here means an on-disk file written by an older CLI stops reading the same.
import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { PluginLockSchema, readPluginLock } from "../src/plugins.ts";
import { RuntimeStateSchema, loadRuntimeState } from "../src/runtime-state.ts";
import { readThemeManifestFile } from "../src/theme-assets.ts";

function tmpFile(name: string, content: string): string {
  const path = join(mkdtempSync(join(tmpdir(), "marchyo-compat-")), name);
  writeFileSync(path, content);
  return path;
}

const lockEntry = {
  id: "example.hello",
  name: "Example",
  version: "1",
  kinds: ["bar-widget"],
  entryPoints: { barWidget: "Panel.qml" },
  prefix: null,
  storePath: "/nix/store/aaaa-example",
  source: { url: "https://example.com/p.git", rev: "0123456789abcdef" },
};

describe("plugin lock file", () => {
  test("a persisted lock parses to the identical value", () => {
    const lock = { lockVersion: 1 as const, plugins: [lockEntry, { ...lockEntry, id: "b", prefix: "!", source: null }] };
    expect(readPluginLock(tmpFile("plugins.lock.json", JSON.stringify(lock)))).toEqual(lock);
  });

  test("unknown keys are stripped, not rejected", () => {
    const lock = { lockVersion: 1, extra: true, plugins: [{ ...lockEntry, future: 1 }] };
    expect(readPluginLock(tmpFile("plugins.lock.json", JSON.stringify(lock)))).toEqual({
      lockVersion: 1 as const,
      plugins: [lockEntry],
    });
  });

  test("wrong lockVersion, missing nullable and bad types are rejected", () => {
    expect(PluginLockSchema.safeParse({ lockVersion: 2, plugins: [] }).success).toBe(false);
    const { source: _s, ...noSource } = lockEntry;
    expect(PluginLockSchema.safeParse({ lockVersion: 1, plugins: [noSource] }).success).toBe(false);
    expect(
      PluginLockSchema.safeParse({ lockVersion: 1, plugins: [{ ...lockEntry, entryPoints: { a: 1 } }] }).success,
    ).toBe(false);
    expect(readPluginLock(tmpFile("plugins.lock.json", "not json"))).toBeNull();
  });
});

describe("runtime state", () => {
  test("accepts primitive override values including null", () => {
    const state = { schemaVersion: 1, overrides: { a: "x", b: 2, c: true, d: null } };
    expect(RuntimeStateSchema.parse(state)).toEqual(state);
  });

  test("strict: unknown top-level keys are rejected", () => {
    expect(RuntimeStateSchema.safeParse({ schemaVersion: 1, overrides: {}, extra: 1 }).success).toBe(false);
  });

  test("rejects non-positive or fractional schemaVersion and non-primitive values", () => {
    for (const v of [0, -1, 1.5, "1"]) {
      expect(RuntimeStateSchema.safeParse({ schemaVersion: v, overrides: {} }).success).toBe(false);
    }
    expect(RuntimeStateSchema.safeParse({ schemaVersion: 1, overrides: { a: {} } }).success).toBe(false);
    expect(RuntimeStateSchema.safeParse({ schemaVersion: 1, overrides: { a: [1] } }).success).toBe(false);
  });

  test("an invalid file degrades to the empty state with a warning", async () => {
    const warnings: string[] = [];
    const path = tmpFile("runtime.json", JSON.stringify({ schemaVersion: 1, overrides: {}, extra: 1 }));
    const state = await loadRuntimeState(path, (m) => warnings.push(m));
    expect(state).toEqual({ schemaVersion: 1, overrides: {} });
    expect(warnings).toHaveLength(1);
  });
});

describe("theme manifest defaults", () => {
  const themes = [{ name: "jylhis-dark", variant: "dark" as const, dir: "/d" }];

  test("object form without followWallpaper defaults it to false", async () => {
    const m = await readThemeManifestFile(tmpFile("manifest.json", JSON.stringify({ themes })));
    expect(m).toEqual({ themes, followWallpaper: false });
  });

  test("object form keeps an explicit followWallpaper", async () => {
    const m = await readThemeManifestFile(
      tmpFile("manifest.json", JSON.stringify({ themes, followWallpaper: true })),
    );
    expect(m.followWallpaper).toBe(true);
  });

  test("legacy bare array still parses with default settings", async () => {
    const m = await readThemeManifestFile(tmpFile("manifest.json", JSON.stringify(themes)));
    expect(m).toEqual({ themes, followWallpaper: false });
  });

  test("invalid variant degrades to empty with a warning", async () => {
    const warnings: string[] = [];
    const bad = [{ name: "x", variant: "sepia", dir: "/d" }];
    const m = await readThemeManifestFile(tmpFile("manifest.json", JSON.stringify(bad)), (w) =>
      warnings.push(w),
    );
    expect(m).toEqual({ themes: [], followWallpaper: false });
    expect(warnings).toHaveLength(1);
  });
});
