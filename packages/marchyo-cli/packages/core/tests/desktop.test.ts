import { describe, expect, test } from "bun:test";
import { hyprctlDispatchArgv, luaString } from "../src/desktop.ts";

describe("luaString", () => {
  test("wraps plain text in double quotes", () => {
    expect(luaString("class:kitty")).toBe('"class:kitty"');
  });

  test("escapes backslashes and quotes", () => {
    expect(luaString('a"b\\c')).toBe('"a\\"b\\\\c"');
  });

  test("escapes control characters as decimal escapes", () => {
    expect(luaString("a\nb\t\u0000")).toBe('"a\\010b\\009\\000"');
  });

  test("passes non-ASCII text through", () => {
    expect(luaString("ä")).toBe('"ä"');
  });
});

describe("hyprctlDispatchArgv", () => {
  test("passes the Lua expression as a single argument", () => {
    expect(hyprctlDispatchArgv("hl.dsp.exit()")).toEqual([
      "hyprctl",
      "dispatch",
      "hl.dsp.exit()",
    ]);
  });
});
