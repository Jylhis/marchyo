import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  parseShellStyle,
  patchShellStyle,
  readShellStyle,
  shellStylePath,
} from "../src/shell-style.ts";
import { mergeState } from "../src/state.ts";

const scratch = (): string => join(mkdtempSync(join(tmpdir(), "marchyo-style-")), "shell", "style.json");

test("shellStylePath follows XDG_STATE_HOME", () => {
  expect(shellStylePath({ XDG_STATE_HOME: "/s" })).toBe("/s/marchyo/shell/style.json");
});

test("a missing or corrupt file reads as the empty style", () => {
  const path = scratch();
  expect(readShellStyle(path)).toEqual({});
});

test("parseShellStyle drops unknown keys and wrongly typed values", () => {
  expect(
    parseShellStyle({
      reduceMotion: "yes",
      uiFont: "Inter",
      barPosition: "left",
      barBackground: "clear",
      extra: 1,
    }),
  ).toEqual({ uiFont: "Inter", barBackground: "clear" });
  expect(parseShellStyle([1])).toEqual({});
});

test("patchShellStyle merges keys, deletes on null and writes atomically", async () => {
  const path = scratch();
  await patchShellStyle({ reduceMotion: true, uiFont: "Inter" }, path);
  await patchShellStyle({ barPosition: "bottom" }, path);
  expect(readShellStyle(path)).toEqual({
    reduceMotion: true,
    uiFont: "Inter",
    barPosition: "bottom",
  });
  await patchShellStyle({ uiFont: null, reduceMotion: false }, path);
  expect(JSON.parse(readFileSync(path, "utf8"))).toEqual({
    reduceMotion: false,
    barPosition: "bottom",
  });
  expect(readdirSync(join(path, ".."))).toEqual(["style.json"]);
});

test("mergeState merges theme.appearance across system and user state", () => {
  const merged = mergeState(
    { theme: { variant: "dark", appearance: { gaps: true } } },
    { theme: { appearance: { reduceMotion: true } } },
  );
  expect(merged.theme).toEqual({
    variant: "dark",
    appearance: { gaps: true, reduceMotion: true },
  });
});
