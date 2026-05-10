import { test, expect } from "bun:test";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { mkdtempSync, rmSync } from "node:fs";
import {
  StateSchema,
  readState,
  writeState,
  mergeState,
  EMPTY_STATE,
} from "../src/state.ts";

function tempPath(): string {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-cli-test-"));
  return join(dir, "state.json");
}

test("StateSchema accepts empty object", () => {
  expect(StateSchema.parse({})).toEqual({});
});

test("StateSchema accepts theme variant", () => {
  expect(StateSchema.parse({ theme: { variant: "dark" } })).toEqual({
    theme: { variant: "dark" },
  });
});

test("StateSchema rejects invalid theme variant", () => {
  expect(() => StateSchema.parse({ theme: { variant: "neon" } })).toThrow();
});

test("StateSchema rejects unknown top-level keys", () => {
  expect(() => StateSchema.parse({ unknownKey: 1 })).toThrow();
});

test("readState returns empty when both paths absent", async () => {
  const path = tempPath();
  expect(await readState(path, path)).toEqual(EMPTY_STATE);
  rmSync(path.replace(/\/state\.json$/, ""), { recursive: true, force: true });
});

test("readState user file overlays system file", async () => {
  const sysDir = mkdtempSync(join(tmpdir(), "marchyo-sys-"));
  const usrDir = mkdtempSync(join(tmpdir(), "marchyo-usr-"));
  try {
    const sysPath = join(sysDir, "state.json");
    const usrPath = join(usrDir, "state.json");
    await writeState({ theme: { variant: "dark" } }, { path: sysPath });
    await writeState({ theme: { variant: "light" } }, { path: usrPath });
    expect(await readState(sysPath, usrPath)).toEqual({
      theme: { variant: "light" },
    });
  } finally {
    rmSync(sysDir, { recursive: true, force: true });
    rmSync(usrDir, { recursive: true, force: true });
  }
});

test("userStatePath honors XDG_CONFIG_HOME", async () => {
  const { userStatePath } = await import("../src/state.ts");
  expect(userStatePath({ XDG_CONFIG_HOME: "/tmp/xdg" })).toBe(
    "/tmp/xdg/marchyo/state.json",
  );
});

test("userStatePath falls back to ~/.config when XDG unset", async () => {
  const { userStatePath } = await import("../src/state.ts");
  const path = userStatePath({});
  expect(path.endsWith("/.config/marchyo/state.json")).toBe(true);
});

test("writeState then readState round-trips via explicit path", async () => {
  const path = tempPath();
  const res = await writeState({ theme: { variant: "light" } }, { path });
  expect(res.path).toBe(path);
  // readState merges system+user; pass the temp file as both so we exercise
  // the round-trip without touching real /etc/* or $HOME paths.
  expect(await readState(path, path)).toEqual({ theme: { variant: "light" } });
  rmSync(path.replace(/\/state\.json$/, ""), { recursive: true, force: true });
});

test("mergeState preserves unrelated keys", () => {
  const merged = mergeState(
    { theme: { variant: "dark" }, _flake: { path: "/a" } },
    { theme: { variant: "light" } },
  );
  expect(merged.theme?.variant).toBe("light");
  expect(merged._flake?.path).toBe("/a");
});
