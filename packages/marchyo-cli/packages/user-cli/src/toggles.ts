import { existsSync } from "node:fs";
import { rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import {
  type ChangeContext,
  type ChangeSpec,
  type State,
  captureArgv,
  hyprctlGetOptionArgv,
  hyprctlKeywordArgv,
  hyprlandAvailable,
  loadRuntimeState,
  makoctlArgv,
  notifySendArgv,
  runtimeStatePath,
  systemctlUserArgv,
} from "@marchyo/core";

// The F3.2 runtime toggles. Each entry provides: a live-state probe (used
// by `toggle <name> --status` and flip-with-no-argument), on/off actuation
// (the ChangeSpec's runtimeApply, value = boolean "feature on"), and a
// revert to the declarative default. Probe seams (capture) are injectable
// for tests.

export type Capture = (
  argv: string[],
) => Promise<{ code: number; stdout: string }>;

type ToggleDef = {
  name: string;
  // Live state, or null when unknowable (falls back to the recorded
  // override, then `defaultOn`).
  probe: (capture: Capture) => Promise<boolean | null>;
  defaultOn: boolean;
  setOn: (ctx: ChangeContext) => Promise<void>;
  setOff: (ctx: ChangeContext) => Promise<void>;
  // Declarative default restore (runtimeRevert).
  revert: (ctx: ChangeContext) => Promise<void>;
  // Only hybrid-gpu persists; everything else is runtime-only.
  applyOnly?: boolean;
  stateWrite?: (prev: State, on: boolean) => State;
  stateDelete?: (prev: State) => State;
};

async function safeExec(ctx: ChangeContext, argv: string[]): Promise<void> {
  try {
    await ctx.exec(argv);
  } catch {
    // best-effort actuation
  }
}

async function notify(
  ctx: ChangeContext,
  summary: string,
  body: string,
): Promise<void> {
  await safeExec(ctx, notifySendArgv(summary, body));
}

// -- probes ----------------------------------------------------------------

async function unitActive(capture: Capture, unit: string): Promise<boolean> {
  const r = await capture(["systemctl", "--user", "is-active", "--quiet", unit]);
  return r.code === 0;
}

async function getOptionFloat(
  capture: Capture,
  option: string,
): Promise<number | null> {
  if (!hyprlandAvailable()) return null;
  const r = await capture(hyprctlGetOptionArgv(option));
  if (r.code !== 0) return null;
  try {
    const parsed = JSON.parse(r.stdout) as { float?: number; int?: number };
    return parsed.float ?? parsed.int ?? null;
  } catch {
    return null;
  }
}

function screensaverMarkerPath(): string {
  return join(
    process.env.XDG_RUNTIME_DIR ?? "/tmp",
    "marchyo-screensaver.off",
  );
}

const SUSPEND_INHIBIT_TAG = "marchyo-suspend-inhibit";

// Device names from `hyprctl -j devices` matching a predicate (touchpads /
// touch screens).
async function deviceNames(
  capture: Capture,
  pick: (section: "mice" | "touch", name: string) => boolean,
): Promise<string[]> {
  if (!hyprlandAvailable()) return [];
  const r = await capture(["hyprctl", "-j", "devices"]);
  if (r.code !== 0) return [];
  try {
    const parsed = JSON.parse(r.stdout) as {
      mice?: Array<{ name?: string }>;
      touch?: Array<{ name?: string }>;
    };
    const names: string[] = [];
    for (const m of parsed.mice ?? []) {
      if (m.name && pick("mice", m.name)) names.push(m.name);
    }
    for (const t of parsed.touch ?? []) {
      if (t.name && pick("touch", t.name)) names.push(t.name);
    }
    return names;
  } catch {
    return [];
  }
}

async function setDevicesEnabled(
  ctx: ChangeContext,
  pick: (section: "mice" | "touch", name: string) => boolean,
  enabled: boolean,
): Promise<void> {
  const names = await deviceNames(captureArgv, pick);
  for (const name of names) {
    await safeExec(
      ctx,
      hyprctlKeywordArgv(`device[${name}]:enabled`, enabled ? "1" : "0"),
    );
  }
}

const pickTouchpad = (section: "mice" | "touch", name: string): boolean =>
  section === "mice" && /touchpad/i.test(name);
const pickTouchscreen = (section: "mice" | "touch", _name: string): boolean =>
  section === "touch";

// -- definitions -----------------------------------------------------------

export const TOGGLES: ToggleDef[] = [
  {
    // "on" = spaced tiles (omarchy look); marchyo's declarative default is
    // the zero-gap tmux grid.
    name: "gaps",
    defaultOn: false,
    probe: async (capture) => {
      const v = await getOptionFloat(capture, "general:gaps_out");
      return v === null ? null : v > 0;
    },
    setOn: async (ctx) => {
      await safeExec(ctx, hyprctlKeywordArgv("general:gaps_in", "5"));
      await safeExec(ctx, hyprctlKeywordArgv("general:gaps_out", "10"));
    },
    setOff: async (ctx) => {
      await safeExec(ctx, hyprctlKeywordArgv("general:gaps_in", "0"));
      await safeExec(ctx, hyprctlKeywordArgv("general:gaps_out", "0"));
    },
    revert: async (ctx) => {
      await safeExec(ctx, hyprctlKeywordArgv("general:gaps_in", "0"));
      await safeExec(ctx, hyprctlKeywordArgv("general:gaps_out", "0"));
    },
  },
  {
    name: "transparency",
    defaultOn: false,
    probe: async (capture) => {
      const v = await getOptionFloat(capture, "decoration:active_opacity");
      return v === null ? null : v < 1;
    },
    setOn: async (ctx) => {
      await safeExec(ctx, hyprctlKeywordArgv("decoration:active_opacity", "0.90"));
      await safeExec(
        ctx,
        hyprctlKeywordArgv("decoration:inactive_opacity", "0.80"),
      );
    },
    setOff: async (ctx) => {
      await safeExec(ctx, hyprctlKeywordArgv("decoration:active_opacity", "1.0"));
      await safeExec(
        ctx,
        hyprctlKeywordArgv("decoration:inactive_opacity", "1.0"),
      );
    },
    revert: async (ctx) => {
      await safeExec(ctx, hyprctlKeywordArgv("decoration:active_opacity", "1.0"));
      await safeExec(
        ctx,
        hyprctlKeywordArgv("decoration:inactive_opacity", "1.0"),
      );
    },
  },
  {
    // Absorbed from marchyo-nightlight-toggle: hyprsunset runtime override,
    // 4000K warm / 6500K neutral. No query interface — state rides the
    // override (marker file dropped).
    name: "nightlight",
    defaultOn: false,
    probe: async () => null,
    setOn: async (ctx) => {
      await safeExec(ctx, ["hyprsunset", "--temperature", "4000"]);
      await notify(ctx, "Nightlight", "On (4000K)");
    },
    setOff: async (ctx) => {
      await safeExec(ctx, ["hyprsunset", "--temperature", "6500"]);
      await notify(ctx, "Nightlight", "Off");
    },
    revert: async (ctx) => {
      await safeExec(ctx, ["hyprsunset", "--temperature", "6500"]);
    },
  },
  {
    name: "waybar",
    defaultOn: true,
    probe: (capture) => unitActive(capture, "waybar.service"),
    setOn: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("start", "waybar.service"));
    },
    setOff: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("stop", "waybar.service"));
    },
    revert: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("start", "waybar.service"));
    },
  },
  {
    name: "touchpad",
    defaultOn: true,
    probe: async () => null,
    setOn: (ctx) => setDevicesEnabled(ctx, pickTouchpad, true),
    setOff: (ctx) => setDevicesEnabled(ctx, pickTouchpad, false),
    revert: (ctx) => setDevicesEnabled(ctx, pickTouchpad, true),
  },
  {
    name: "touchscreen",
    defaultOn: true,
    probe: async () => null,
    setOn: (ctx) => setDevicesEnabled(ctx, pickTouchscreen, true),
    setOff: (ctx) => setDevicesEnabled(ctx, pickTouchscreen, false),
    revert: (ctx) => setDevicesEnabled(ctx, pickTouchscreen, true),
  },
  {
    // Absorbed from marchyo-idle-toggle.
    name: "idle",
    defaultOn: true,
    probe: (capture) => unitActive(capture, "hypridle.service"),
    setOn: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("start", "hypridle.service"));
      await notify(ctx, "Idle lock", "Enabled");
    },
    setOff: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("stop", "hypridle.service"));
      await notify(ctx, "Idle lock", "Disabled — screen will stay awake");
    },
    revert: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("start", "hypridle.service"));
    },
  },
  {
    // The idle-triggered tte screensaver: gated by a runtime-dir marker the
    // launcher (modules/home/screensaver.nix) checks before opening.
    name: "screensaver",
    defaultOn: true,
    probe: async () => !existsSync(screensaverMarkerPath()),
    setOn: async () => {
      await rm(screensaverMarkerPath(), { force: true });
    },
    setOff: async () => {
      await writeFile(screensaverMarkerPath(), "");
    },
    revert: async () => {
      await rm(screensaverMarkerPath(), { force: true });
    },
  },
  {
    // Absorbed from marchyo-dnd-toggle: "off" = do-not-disturb (mako mode
    // from modules/home/mako.nix) + waybar indicator poke (SIGRTMIN+9).
    name: "notifications",
    defaultOn: true,
    probe: async (capture) => {
      const r = await capture(makoctlArgv("mode"));
      if (r.code !== 0) return null;
      return !r.stdout.includes("do-not-disturb");
    },
    setOn: async (ctx) => {
      await safeExec(ctx, makoctlArgv("mode", "-r", "do-not-disturb"));
      await safeExec(ctx, ["pkill", "-SIGRTMIN+9", "waybar"]);
    },
    setOff: async (ctx) => {
      await safeExec(ctx, makoctlArgv("mode", "-a", "do-not-disturb"));
      await safeExec(ctx, ["pkill", "-SIGRTMIN+9", "waybar"]);
    },
    revert: async (ctx) => {
      await safeExec(ctx, makoctlArgv("mode", "-r", "do-not-disturb"));
      await safeExec(ctx, ["pkill", "-SIGRTMIN+9", "waybar"]);
    },
  },
  {
    // "off" = block sleep/idle via a tagged systemd inhibitor.
    name: "suspend",
    defaultOn: true,
    probe: async (capture) => {
      const r = await capture(["pgrep", "-f", SUSPEND_INHIBIT_TAG]);
      return r.code !== 0;
    },
    setOn: async (ctx) => {
      await safeExec(ctx, ["pkill", "-f", SUSPEND_INHIBIT_TAG]);
      await notify(ctx, "Suspend", "Automatic sleep allowed");
    },
    setOff: async (ctx) => {
      try {
        const proc = Bun.spawn(
          [
            "systemd-inhibit",
            `--what=sleep:idle`,
            "--who=marchyo",
            `--why=${SUSPEND_INHIBIT_TAG}`,
            "sleep",
            "infinity",
          ],
          { stdout: "ignore", stderr: "ignore", stdin: "ignore" },
        );
        proc.unref();
      } catch {
        // systemd-inhibit unavailable
      }
      await notify(ctx, "Suspend", "Automatic sleep inhibited");
    },
    revert: async (ctx) => {
      await safeExec(ctx, ["pkill", "-f", SUSPEND_INHIBIT_TAG]);
    },
  },
  {
    // Hardware-mode change — no safe live leg; --apply-only, persists
    // marchyo.graphics.prime.enable through cli-state.json.
    name: "hybrid-gpu",
    defaultOn: false,
    applyOnly: true,
    probe: async () => null,
    setOn: async () => {},
    setOff: async () => {},
    revert: async () => {},
    stateWrite: (prev, on) => ({
      ...prev,
      graphics: { ...prev.graphics, prime: { enable: on } },
    }),
    stateDelete: (prev) => {
      const next = { ...prev };
      delete next.graphics;
      return next;
    },
  },
];

export function toggleByName(name: string): ToggleDef | null {
  return TOGGLES.find((t) => t.name === name) ?? null;
}

export function toggleKey(name: string): string {
  return `toggle.${name}`;
}

// Effective state: live probe → recorded override → declarative default.
export async function toggleState(
  def: ToggleDef,
  capture: Capture = captureArgv,
): Promise<boolean> {
  const probed = await def.probe(capture);
  if (probed !== null) return probed;
  const state = await loadRuntimeState(runtimeStatePath());
  const recorded = state.overrides[toggleKey(def.name)];
  if (typeof recorded === "boolean") return recorded;
  return def.defaultOn;
}

export function toggleSpecFor(def: ToggleDef): ChangeSpec {
  return {
    key: toggleKey(def.name),
    runtimeApply: async (ctx) => {
      const on =
        typeof ctx.value === "boolean"
          ? ctx.value
          : !(await toggleState(def));
      if (on) await def.setOn(ctx);
      else await def.setOff(ctx);
      return on;
    },
    runtimeRevert: async (ctx) => {
      await def.revert(ctx);
    },
    ...(def.stateWrite
      ? {
          stateWrite: (prev: State, value) =>
            def.stateWrite!(prev, value === true),
        }
      : {}),
    ...(def.stateDelete ? { stateDelete: def.stateDelete } : {}),
  };
}
