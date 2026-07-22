import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  RUNTIME_SCHEMA_VERSION,
  clearOverride,
  emptyRuntimeState,
  listOverrides,
  loadRuntimeState,
  runtimeStatePath,
  saveRuntimeState,
  setOverride,
} from "../src/runtime-state.ts";

function tempStatePath(): { dir: string; path: string } {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-runtime-"));
  return { dir, path: join(dir, "nested", "runtime.json") };
}

describe("runtimeStatePath", () => {
  test("honors XDG_STATE_HOME", () => {
    expect(runtimeStatePath({ XDG_STATE_HOME: "/xdg/state" })).toBe(
      "/xdg/state/marchyo/runtime.json",
    );
  });

  test("falls back to ~/.local/state", () => {
    expect(runtimeStatePath({})).toContain("/.local/state/marchyo/runtime.json");
  });
});

describe("loadRuntimeState", () => {
  test("missing file yields empty state without warning", async () => {
    const { dir, path } = tempStatePath();
    try {
      const warnings: string[] = [];
      const state = await loadRuntimeState(path, (m) => warnings.push(m));
      expect(state).toEqual(emptyRuntimeState());
      expect(warnings).toEqual([]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("invalid JSON warns and yields empty state", async () => {
    const { dir, path } = tempStatePath();
    try {
      await saveRuntimeState(emptyRuntimeState(), path);
      writeFileSync(path, "{nope");
      const warnings: string[] = [];
      const state = await loadRuntimeState(path, (m) => warnings.push(m));
      expect(state).toEqual(emptyRuntimeState());
      expect(warnings.length).toBe(1);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("newer schemaVersion warns and yields empty state", async () => {
    const { dir, path } = tempStatePath();
    try {
      await saveRuntimeState(emptyRuntimeState(), path);
      writeFileSync(
        path,
        JSON.stringify({
          schemaVersion: RUNTIME_SCHEMA_VERSION + 1,
          overrides: { "toggle.gaps": false },
        }),
      );
      const warnings: string[] = [];
      const state = await loadRuntimeState(path, (m) => warnings.push(m));
      expect(state.overrides).toEqual({});
      expect(warnings[0]).toContain("newer than this CLI");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("set/clear/list overrides", () => {
  test("round-trips values and sorts listing by key", async () => {
    const { dir, path } = tempStatePath();
    try {
      await setOverride("toggle.nightlight", true, path);
      await setOverride("theme.selection", "gruvbox", path);
      const state = await loadRuntimeState(path);
      expect(listOverrides(state)).toEqual([
        { key: "theme.selection", value: "gruvbox" },
        { key: "toggle.nightlight", value: true },
      ]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("clearOverride reports whether the key existed", async () => {
    const { dir, path } = tempStatePath();
    try {
      await setOverride("toggle.idle", false, path);
      expect(await clearOverride("toggle.idle", path)).toBe(true);
      expect(await clearOverride("toggle.idle", path)).toBe(false);
      const state = await loadRuntimeState(path);
      expect(state.overrides).toEqual({});
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("save is atomic (no .tmp leftovers) and creates parent dirs", async () => {
    const { dir, path } = tempStatePath();
    try {
      await setOverride("a", 1, path);
      const listing = await Array.fromAsync(
        new Bun.Glob("*").scan({ cwd: join(dir, "nested") }),
      );
      expect(listing).toEqual(["runtime.json"]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
