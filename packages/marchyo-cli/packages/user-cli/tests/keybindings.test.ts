import { test, expect } from "bun:test";
import { formatSheetRows, keybindingsSheetPath } from "../src/commands/menu.ts";

const sheet = [
  { combo: "SUPER + return", description: "Terminal", group: "Apps" },
  { combo: "SUPER + CTRL + L", description: "Lock", group: "Session" },
];

test("sheet rows keep table order", () => {
  const rows = formatSheetRows(sheet);
  expect(rows).toHaveLength(2);
  expect(rows[0]).toContain("SUPER + return");
  expect(rows[0]).toContain("Terminal");
  expect(rows[1]).toMatch(/^Session\s+SUPER \+ CTRL \+ L\s+Lock$/);
});

test("described binds outside the table are listed as Other", () => {
  const rows = formatSheetRows(sheet, [
    { description: "Terminal", modmask: 64, key: "Return", keycode: 0 },
    { description: "My tool", modmask: 65, key: "U", keycode: 0 },
    { modmask: 64, key: "R", keycode: 0 },
  ]);
  expect(rows).toHaveLength(3);
  expect(rows[2]).toMatch(/^Other\s+SUPER\+SHIFT\+U\s+My tool$/);
});

test("a downstream bind reusing a description on another chord is kept", () => {
  const rows = formatSheetRows(
    [...sheet, { combo: "SUPER + 1", description: "Switch to workspace 1", group: "Workspaces" }],
    [
      { description: "Terminal", modmask: 65, key: "T", keycode: 0 },
      { description: "Lock", modmask: 68, key: "l", keycode: 0 },
      { description: "Switch to workspace 1", modmask: 64, key: "", keycode: 10 },
    ],
  );
  expect(rows).toHaveLength(4);
  expect(rows[3]).toMatch(/^Other\s+SUPER\+SHIFT\+T\s+Terminal$/);
});

test("the sheet lives under XDG_CONFIG_HOME", () => {
  expect(keybindingsSheetPath({ XDG_CONFIG_HOME: "/x" })).toBe("/x/marchyo/keybindings.json");
});
