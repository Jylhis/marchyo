import { test, expect } from "bun:test";
import { join } from "node:path";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import type { ChangeContext } from "@marchyo/core";
import {
  APPEARANCE_ITEMS,
} from "../src/commands/menu.ts";
import {
  animationsLua,
  cornersChangeBase,
  cornersLua,
  declarativeAppearance,
  fullscreenDesktopLua,
  gapsLua,
  transparencyChangeBase,
  transparencyLua,
} from "../src/commands/appearance.ts";
import {
  closeLua,
  popLua,
  tiledFullscreenLua,
} from "../src/commands/window.ts";
import { TOGGLES } from "../src/toggles.ts";
import { changeRegistry } from "../src/changes.ts";

const CLI = join(import.meta.dir, "..", "src", "cli.tsx");

async function run(args: string[], env: Record<string, string> = {}) {
  const proc = Bun.spawn([process.execPath, CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1", ...env },
  });
  const code = await proc.exited;
  return {
    code,
    stdout: await new Response(proc.stdout).text(),
    stderr: await new Response(proc.stderr).text(),
  };
}

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

test("transparency Lua: opaque, transparent and glassy", () => {
  expect(transparencyLua("opaque", false)).toBe(
    "hl.config({ decoration = { active_opacity = 1.0, inactive_opacity = 1.0, blur = { enabled = false } } })",
  );
  expect(transparencyLua("opaque", true)).toContain("blur = { enabled = true }");
  expect(transparencyLua("transparent", false)).toContain("active_opacity = 0.92");
  expect(transparencyLua("transparent", false)).toContain("blur = { enabled = false }");
  expect(transparencyLua("glassy", false)).toContain("blur = { enabled = true }");
});

test("corners, animations, gaps and fullscreen-desktop Lua", () => {
  expect(cornersLua("rounded")).toContain("rounding = 6, rounding_power = 3");
  expect(cornersLua("sharp")).toContain("rounding = 0");
  expect(cornersLua("theme")).toContain("rounding = 0");
  expect(animationsLua(false)).toBe("hl.config({ animations = { enabled = false } })");
  expect(gapsLua(true)).toContain("gaps_out = 10");
  expect(fullscreenDesktopLua(true)).toContain("border_size = 0");
  expect(fullscreenDesktopLua(false, "rounded")).toContain("border_size = 2");
  expect(fullscreenDesktopLua(false, "rounded")).toContain("rounding = 6");
  expect(fullscreenDesktopLua(false, "theme", true)).toContain("gaps_out = 10");
  expect(fullscreenDesktopLua(false, "theme", false)).toContain("gaps_out = 0");
});

test("declarativeAppearance reads the module-written file and falls back safely", () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-appearance-"));
  const path = join(dir, "appearance.json");
  expect(declarativeAppearance(path).transparency).toBe("opaque");
  writeFileSync(
    path,
    JSON.stringify({
      transparency: "glassy",
      corners: "rounded",
      animations: true,
      shellGlass: true,
      gaps: true,
      reduceMotion: true,
      iconTheme: "Papirus",
    }),
  );
  expect(declarativeAppearance(path)).toEqual({
    transparency: "glassy",
    corners: "rounded",
    animations: true,
    shellGlass: true,
    gaps: true,
    reduceMotion: true,
    iconTheme: "Papirus",
  });
  writeFileSync(path, "not json");
  expect(declarativeAppearance(path).corners).toBe("theme");
});

test("transparency and corners specs apply through hyprctl eval and reject bad values", async () => {
  const prev = process.env.HYPRLAND_INSTANCE_SIGNATURE;
  process.env.HYPRLAND_INSTANCE_SIGNATURE = "test";
  try {
    const calls: string[][] = [];
    expect(await transparencyChangeBase.runtimeApply(ctxWith("glassy", calls))).toBe(
      "glassy",
    );
    expect(await cornersChangeBase.runtimeApply(ctxWith("rounded", calls))).toBe(
      "rounded",
    );
    expect(calls.map((c) => c.slice(0, 2))).toEqual([
      ["hyprctl", "eval"],
      ["hyprctl", "eval"],
    ]);
    await expect(
      transparencyChangeBase.runtimeApply(ctxWith("milky", calls)),
    ).rejects.toThrow();
    await expect(cornersChangeBase.runtimeApply(ctxWith(3, calls))).rejects.toThrow();
  } finally {
    if (prev === undefined) delete process.env.HYPRLAND_INSTANCE_SIGNATURE;
    else process.env.HYPRLAND_INSTANCE_SIGNATURE = prev;
  }
});

test("new toggles and appearance specs are registered for runtime restore", () => {
  const names = TOGGLES.map((t) => t.name);
  expect(names).toContain("animations");
  expect(names).toContain("fullscreen-desktop");
  for (const key of [
    "appearance.transparency",
    "appearance.corners",
    "toggle.animations",
    "toggle.fullscreen-desktop",
  ]) {
    expect(changeRegistry.has(key)).toBe(true);
  }
});

test("pop-out and pop-back Lua dispatch sequences", () => {
  const out = popLua("0xabc", false);
  expect(out[0]).toContain('float({ window = "address:0xabc", action = "toggle" })');
  expect(out.some((l) => l.includes("window.pin("))).toBe(true);
  expect(out.at(-1)).toContain('tag = "+pop"');
  const back = popLua("0xabc", true);
  expect(back[0]).toContain("window.pin(");
  expect(back.at(-1)).toContain('tag = "-pop"');
});

test("tiled fullscreen and close Lua", () => {
  expect(tiledFullscreenLua(0)).toContain("client = 2");
  expect(tiledFullscreenLua(2)).toContain("client = 0");
  expect(closeLua("0x1")).toBe('hl.dsp.window.close({ window = "address:0x1" })');
});

test("the Appearance menu groups theme, background, font and window toggles", () => {
  for (const item of [
    "Theme",
    "Background",
    "Font",
    "Transparency",
    "Corners",
    "Animations",
  ]) {
    expect(APPEARANCE_ITEMS).toContain(item as never);
  }
});

test("window with an unknown action exits 2", async () => {
  const r = await run(["window", "teleport"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("unknown window action");
});

test("theme transparency rejects an unknown mode and lists the modes", async () => {
  const bad = await run(["theme", "transparency", "milky"]);
  expect(bad.code).toBe(2);
  const list = await run(["theme", "transparency", "--json"]);
  expect(list.code).toBe(0);
  expect(JSON.parse(list.stdout).transparency.modes).toEqual([
    "opaque",
    "transparent",
    "glassy",
  ]);
});

test("theme corners --revert is accepted without a value", async () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-corners-"));
  const r = await run(["theme", "corners", "--revert"], {
    XDG_STATE_HOME: join(dir, "state"),
    XDG_CONFIG_HOME: join(dir, "config"),
  });
  expect(r.code).toBe(0);
});
