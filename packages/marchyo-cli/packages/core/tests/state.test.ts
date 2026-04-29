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

test("readState returns empty on missing file", async () => {
  const path = tempPath();
  expect(await readState(path)).toEqual(EMPTY_STATE);
  rmSync(path.replace(/\/state\.json$/, ""), { recursive: true, force: true });
});

test("writeState then readState round-trips", async () => {
  const path = tempPath();
  await writeState({ theme: { variant: "light" } }, path);
  expect(await readState(path)).toEqual({ theme: { variant: "light" } });
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
