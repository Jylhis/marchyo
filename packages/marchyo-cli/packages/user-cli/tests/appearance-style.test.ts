import { afterAll, beforeAll, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ChangeContext, State } from "@marchyo/core";
import {
  barBackgroundChangeBase,
  barPositionChangeBase,
  dropThemeAppearance,
  gapsChangeBase,
  iconThemeChangeBase,
  installedIconThemes,
} from "../src/commands/appearance.ts";
import { uiFontSpec } from "../src/commands/font.ts";
import { changeRegistry } from "../src/changes.ts";
import { restoreOrder } from "../src/commands/runtime.ts";

const root = mkdtempSync(join(tmpdir(), "marchyo-appearance-style-"));
const saved = {
  state: process.env.XDG_STATE_HOME,
  config: process.env.XDG_CONFIG_HOME,
  hypr: process.env.HYPRLAND_INSTANCE_SIGNATURE,
};
const style = (): unknown =>
  JSON.parse(readFileSync(join(root, "state", "marchyo", "shell", "style.json"), "utf8"));

beforeAll(() => {
  process.env.XDG_STATE_HOME = join(root, "state");
  process.env.XDG_CONFIG_HOME = join(root, "config");
  process.env.HYPRLAND_INSTANCE_SIGNATURE = "test";
});

afterAll(() => {
  for (const [key, value] of [
    ["XDG_STATE_HOME", saved.state],
    ["XDG_CONFIG_HOME", saved.config],
    ["HYPRLAND_INSTANCE_SIGNATURE", saved.hypr],
  ] as const) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  rmSync(root, { recursive: true, force: true });
});

function ctxWith(value: ChangeContext["value"], calls: string[][]): ChangeContext {
  return {
    rt: {} as ChangeContext["rt"],
    exec: async (argv) => {
      calls.push(argv);
      return 0;
    },
    value,
  };
}

test("every new spec is registered for runtime restore", () => {
  for (const key of [
    "appearance.gaps",
    "appearance.barPosition",
    "appearance.barBackground",
    "appearance.iconTheme",
    "font.ui",
    "toggle.reduce-motion",
  ]) {
    expect(changeRegistry.has(key)).toBe(true);
  }
});

test("gaps applies through hyprctl eval, accepts on/off strings and persists theme.appearance.gaps", async () => {
  const calls: string[][] = [];
  expect(await gapsChangeBase.runtimeApply(ctxWith(true, calls))).toBe(true);
  expect(await gapsChangeBase.runtimeApply(ctxWith("off", calls))).toBe(false);
  expect(calls[0]![2]).toContain("gaps_out = 10");
  expect(calls[1]![2]).toContain("gaps_out = 0");
  await expect(gapsChangeBase.runtimeApply(ctxWith("maybe", calls))).rejects.toThrow();

  const prev: State = { theme: { variant: "dark" } };
  const written = gapsChangeBase.stateWrite!(prev, true);
  expect(written.theme).toEqual({ variant: "dark", appearance: { gaps: true } });
  expect(gapsChangeBase.stateDelete!(written)).toEqual(prev);
});

test("dropThemeAppearance keeps the other appearance and theme keys", () => {
  const state: State = {
    theme: { scheme: "nord", appearance: { gaps: true, reduceMotion: true } },
  };
  expect(dropThemeAppearance(state, "gaps").theme).toEqual({
    scheme: "nord",
    appearance: { reduceMotion: true },
  });
  expect(dropThemeAppearance({ theme: { appearance: { gaps: true } } }, "gaps")).toEqual({});
  expect(dropThemeAppearance({}, "gaps")).toEqual({});
});

test("bar position and background write the shell style file and reject bad values", async () => {
  const calls: string[][] = [];
  expect(await barPositionChangeBase.runtimeApply(ctxWith("bottom", calls))).toBe("bottom");
  expect(await barBackgroundChangeBase.runtimeApply(ctxWith("clear", calls))).toBe("clear");
  expect(style()).toMatchObject({ barPosition: "bottom", barBackground: "clear" });
  await expect(barPositionChangeBase.runtimeApply(ctxWith("left", calls))).rejects.toThrow();
  await expect(barBackgroundChangeBase.runtimeApply(ctxWith("milky", calls))).rejects.toThrow();

  await barPositionChangeBase.runtimeRevert(ctxWith(undefined, calls));
  await barBackgroundChangeBase.runtimeRevert(ctxWith(undefined, calls));
  expect(style()).toEqual({});
  expect(calls).toEqual([]);
});

test("installedIconThemes lists index.theme dirs that declare Directories", () => {
  const dir = join(root, "icons");
  const theme = (name: string, index: string): void => {
    mkdirSync(join(dir, name), { recursive: true });
    writeFileSync(join(dir, name, "index.theme"), index);
  };
  theme("Papirus", "[Icon Theme]\nName=Papirus\nDirectories=48x48/apps\n");
  theme("Adwaita", "[Icon Theme]\nDirectories=scalable/apps\n");
  theme("Cursors", "[Icon Theme]\nInherits=core\n");
  theme("Hidden", "[Icon Theme]\nDirectories=a\nHidden=true\n");
  mkdirSync(join(dir, "no-index"));
  expect(installedIconThemes([dir, join(root, "missing")])).toEqual(["Adwaita", "Papirus"]);
});

test("icon theme sets the dconf key and reverts to the declarative name or resets", async () => {
  const calls: string[][] = [];
  expect(await iconThemeChangeBase.runtimeApply(ctxWith("Papirus-Dark", calls))).toBe(
    "Papirus-Dark",
  );
  expect(calls[0]).toEqual([
    "dconf",
    "write",
    "/org/gnome/desktop/interface/icon-theme",
    "'Papirus-Dark'",
  ]);
  await expect(iconThemeChangeBase.runtimeApply(ctxWith("", calls))).rejects.toThrow();

  await iconThemeChangeBase.runtimeRevert(ctxWith(undefined, calls));
  expect(calls[1]).toEqual(["dconf", "reset", "/org/gnome/desktop/interface/icon-theme"]);

  mkdirSync(join(root, "config", "marchyo"), { recursive: true });
  writeFileSync(
    join(root, "config", "marchyo", "appearance.json"),
    JSON.stringify({ iconTheme: "Adwaita", fontName: "Cantarell 11" }),
  );
  await iconThemeChangeBase.runtimeRevert(ctxWith(undefined, calls));
  expect(calls[2]![3]).toBe("'Adwaita'");
});

// A session whose GTK font is "Inter 12".
const uiFontChangeBase = uiFontSpec(async () => ({ code: 0, stdout: "'Inter 12'\n" }));

test("ui font keeps the current size, updates the shell style and reverts", async () => {
  const calls: string[][] = [];
  expect(await uiFontChangeBase.runtimeApply(ctxWith("Fira Sans", calls))).toBe("Fira Sans");
  expect(calls[0]).toEqual([
    "dconf",
    "write",
    "/org/gnome/desktop/interface/font-name",
    "'Fira Sans 12'",
  ]);
  expect(style()).toMatchObject({ uiFont: "Fira Sans" });
  await expect(uiFontChangeBase.runtimeApply(ctxWith(undefined, calls))).rejects.toThrow();

  await uiFontChangeBase.runtimeRevert(ctxWith(undefined, calls));
  expect(style()).not.toHaveProperty("uiFont");
  expect(calls[1]![3]).toBe("'Cantarell 11'");
});

test("runtime restore replays the theme before the wallpaper, fonts, appearance and toggles", () => {
  const keys = [
    "toggle.gaps",
    "appearance.corners",
    "font.ui",
    "other.thing",
    "bg.image",
    "font.family",
    "theme.selection",
    "theme.generate",
  ].map((key) => ({ key }));
  expect(restoreOrder(keys).map((o) => o.key)).toEqual([
    "theme.generate",
    "theme.selection",
    "bg.image",
    "font.family",
    "font.ui",
    "appearance.corners",
    "toggle.gaps",
    "other.thing",
  ]);
});
