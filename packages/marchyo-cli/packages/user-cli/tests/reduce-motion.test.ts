import { afterEach, expect, test } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ChangeContext, State } from "@marchyo/core";
import { changeRegistry } from "../src/changes.ts";
import { toggleByName, toggleSpecFor, toggleState } from "../src/toggles.ts";

const prev = process.env.XDG_STATE_HOME;
const dir = mkdtempSync(join(tmpdir(), "marchyo-reduce-motion-"));
process.env.XDG_STATE_HOME = dir;
const style = join(dir, "marchyo", "shell", "style.json");

afterEach(() => rmSync(join(dir, "marchyo"), { recursive: true, force: true }));

const ctx = {
  rt: {} as ChangeContext["rt"],
  exec: async () => 0,
  value: undefined,
} satisfies ChangeContext;

test("reduce-motion is a registered runtime change", () => {
  expect(toggleByName("reduce-motion")).not.toBeNull();
  expect(changeRegistry.has("toggle.reduce-motion")).toBe(true);
});

test("reduce-motion writes the style key the shell watches", async () => {
  const def = toggleByName("reduce-motion")!;
  expect(await toggleState(def)).toBe(false);
  await def.setOn(ctx);
  expect(JSON.parse(readFileSync(style, "utf8"))).toEqual({ reduceMotion: true });
  expect(await toggleState(def)).toBe(true);
  await def.setOff(ctx);
  expect(JSON.parse(readFileSync(style, "utf8"))).toEqual({ reduceMotion: false });
});

test("reduce-motion revert drops the key so the declarative value applies", async () => {
  const def = toggleByName("reduce-motion")!;
  await def.setOn(ctx);
  await def.revert(ctx);
  expect(JSON.parse(readFileSync(style, "utf8"))).toEqual({});
  expect(existsSync(join(dir, "marchyo", "shell", "reduce-motion"))).toBe(false);
});

test("reduce-motion persists theme.appearance.reduceMotion without touching the theme", () => {
  const spec = toggleSpecFor(toggleByName("reduce-motion")!);
  const prevState: State = { theme: { variant: "dark", appearance: { gaps: true } } };
  const written = spec.stateWrite!(prevState, true);
  expect(written.theme).toEqual({
    variant: "dark",
    appearance: { gaps: true, reduceMotion: true },
  });
  expect(spec.stateDelete!(written).theme).toEqual({
    variant: "dark",
    appearance: { gaps: true },
  });
  expect(spec.stateDelete!({ theme: { appearance: { reduceMotion: true } } })).toEqual({});
  if (prev === undefined) delete process.env.XDG_STATE_HOME;
  else process.env.XDG_STATE_HOME = prev;
});
