import { expect, test } from "bun:test";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { monitorNixSnippet, monitorSettingsFile } from "../src/commands/launch.ts";

const REPO = join(import.meta.dir, "..", "..", "..");
const CLI = join(REPO, "packages", "user-cli", "src", "cli.tsx");

async function run(args: string[], env: Record<string, string> = {}) {
  const proc = Bun.spawn([process.execPath, CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1", HYPRLAND_INSTANCE_SIGNATURE: "", ...env },
  });
  const code = await proc.exited;
  return {
    code,
    stdout: await new Response(proc.stdout).text(),
    stderr: await new Response(proc.stderr).text(),
  };
}

test("monitorSettingsFile follows XDG_STATE_HOME", () => {
  expect(monitorSettingsFile({ XDG_STATE_HOME: "/s" })).toBe("/s/marchyo/monitors/settings");
  expect(monitorSettingsFile({ XDG_STATE_HOME: "" })).toMatch(
    /\/\.local\/state\/marchyo\/monitors\/settings$/,
  );
});

test("monitor reset deletes the saved display settings and keeps the workspace cache", async () => {
  const dir = `/tmp/marchyo-mon-reset-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const monitors = join(dir, "marchyo", "monitors");
  mkdirSync(monitors, { recursive: true });
  writeFileSync(join(monitors, "settings"), "\t\t\t1.5\t\t\tBOE panel\n");
  writeFileSync(join(monitors, "workspaces"), "0\teDP-1\tBOE panel\n");
  const r = await run(["monitor", "reset"], { XDG_STATE_HOME: dir });
  expect(r.code).toBe(0);
  expect(existsSync(join(monitors, "settings"))).toBe(false);
  expect(existsSync(join(monitors, "workspaces"))).toBe(true);
  rmSync(dir, { recursive: true, force: true });
});

test("monitor reset succeeds when nothing was saved", async () => {
  const dir = `/tmp/marchyo-mon-reset-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const r = await run(["monitor", "reset"], { XDG_STATE_HOME: dir });
  expect(r.code).toBe(0);
});

test("monitor save needs --nix", async () => {
  const r = await run(["monitor", "save"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("marchyo monitor save --nix");
});

test("monitor save --nix needs a Hyprland session", async () => {
  const r = await run(["monitor", "save", "--nix"]);
  expect(r.code).toBe(1);
  expect(r.stdout).toBe("");
});

test("monitorNixSnippet prints mode, position, scale, rotation, mirror and disabled outputs", () => {
  const snippet = monitorNixSnippet([
    {
      id: 0,
      name: "eDP-1",
      width: 2256,
      height: 1504,
      refreshRate: 59.999,
      x: 0,
      y: 0,
      scale: 1.5,
      transform: 0,
      mirrorOf: "none",
    },
    {
      id: 1,
      name: "DP-3",
      width: 3840,
      height: 2160,
      refreshRate: 143.99,
      x: 1504,
      y: 0,
      scale: 2,
      transform: 1,
      mirrorOf: "none",
    },
    {
      id: 2,
      name: "HDMI-A-1",
      width: 1920,
      height: 1080,
      refreshRate: 60,
      x: 0,
      y: 0,
      scale: 1,
      transform: 0,
      mirrorOf: 0,
    },
    { id: 3, name: "DP-4", disabled: true, width: 0, height: 0, refreshRate: 0, x: 0, y: 0, scale: 1 },
    { id: 4, name: 'bad"name', width: 1, height: 1, refreshRate: 1, x: 0, y: 0, scale: 1 },
  ]);
  expect(snippet).toBe(`marchyo.monitors = [
  {
    output = "eDP-1";
    mode = "2256x1504@60";
    position = "0x0";
    scale = 1.5;
  }
  {
    output = "DP-3";
    mode = "3840x2160@143.99";
    position = "1504x0";
    scale = 2;
    transform = 1;
  }
  {
    output = "HDMI-A-1";
    mode = "1920x1080@60";
    position = "0x0";
    scale = 1;
    extraSettings.mirror = "eDP-1";
  }
  {
    output = "DP-4";
    enable = false;
  }
];
`);
});

test("monitorNixSnippet of no monitors is an empty list", () => {
  expect(monitorNixSnippet([])).toBe("marchyo.monitors = [\n\n];\n");
});
