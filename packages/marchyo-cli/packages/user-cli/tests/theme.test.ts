import { describe, expect, test } from "bun:test";
import { hyprctlEvalArgv, hyprctlKeywordArgv } from "@marchyo/core";
import {
  hyprlandConfigLua,
  hyprlandConfigTable,
} from "../src/commands/theme.ts";

describe("hyprctlEvalArgv", () => {
  test("builds the eval argv with the code as one argument", () => {
    const code = 'hl.config({ ["general"] = { ["col.active_border"] = "rgba(e0a33aff)" } })';
    expect(hyprctlEvalArgv(code)).toEqual(["hyprctl", "eval", code]);
  });

  test("the keyword builder still exists for hyprlang holdouts", () => {
    expect(hyprctlKeywordArgv("general:gaps_in", "5")).toEqual([
      "hyprctl",
      "keyword",
      "general:gaps_in",
      "5",
    ]);
  });
});

describe("hyprlandConfigTable", () => {
  test("groups section:subkey lines, split on the first colon and space", () => {
    // The exact shape theme-runtime.nix's hyprlandKeywordsFor emits.
    const conf = [
      "misc:background_color rgb(0d0f14)",
      "general:col.active_border rgba(e0a33aff)",
      "general:col.inactive_border rgba(3a4150ff)",
      "",
    ].join("\n");
    expect(hyprlandConfigTable(conf)).toEqual({
      misc: { background_color: "rgb(0d0f14)" },
      general: {
        "col.active_border": "rgba(e0a33aff)",
        "col.inactive_border": "rgba(3a4150ff)",
      },
    });
  });

  test("later lines override earlier ones for the same key", () => {
    const conf = "general:gaps_in 5\ngeneral:gaps_in 0";
    expect(hyprlandConfigTable(conf)).toEqual({ general: { gaps_in: "0" } });
  });

  test("skips malformed lines: no space, no colon, or leading colon", () => {
    const conf = ["", "nocolon value", ":leadingcolon value", "novalue"].join(
      "\n",
    );
    expect(hyprlandConfigTable(conf)).toEqual({});
  });

  test("empty and whitespace-only input yield {}", () => {
    expect(hyprlandConfigTable("")).toEqual({});
    expect(hyprlandConfigTable("\n\n")).toEqual({});
  });
});

describe("hyprlandConfigLua", () => {
  test("renders the verified hl.config table literal", () => {
    // Byte-for-byte the form validated live against Hyprland's Lua runtime.
    expect(
      hyprlandConfigLua({
        general: {
          "col.active_border": "rgba(e0a33aff)",
          "col.inactive_border": "rgba(3a4150ff)",
        },
        misc: { background_color: "rgb(0d0f14)" },
      }),
    ).toBe(
      'hl.config({ ["general"] = { ["col.active_border"] = "rgba(e0a33aff)", ' +
        '["col.inactive_border"] = "rgba(3a4150ff)" }, ' +
        '["misc"] = { ["background_color"] = "rgb(0d0f14)" } })',
    );
  });

  test("empty table renders an empty config call", () => {
    expect(hyprlandConfigLua({})).toBe("hl.config({  })");
  });
});
