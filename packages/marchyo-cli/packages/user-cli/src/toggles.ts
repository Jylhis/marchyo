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
  shellInstalled,
  shellIpc,
  systemctlUserArgv,
} from "@marchyo/core";

// The runtime toggles. Each entry provides: a live-state probe (used
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
  // Flip in one step and report the new state, or null to flip through
  // probe + setOn/setOff. For backends that toggle atomically but expose no
  // read-only state query (the shell bar and do-not-disturb).
  flip?: () => Promise<boolean | null>;
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
const CAFFEINE_INHIBIT_TAG = "marchyo-caffeine-inhibit";

// Self-excluding pgrep pattern: bracket the first char so a concurrent
// `pgrep -f <pattern>` never matches its own (or a peer's) argv — only the
// real `--why=<tag>` inhibitor. See shell/Bar/CaffeineWidget.qml for the same
// idiom. Keep the literal tag for `--why=` and `pkill -f`.
const probePattern = (tag: string): string => `[${tag[0]}]${tag.slice(1)}`;

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

// One shell IPC call, best effort: the reply, or null when the shell is not
// running or rejects the call.
async function shellCall(
  invoke: () => Promise<string>,
): Promise<string | null> {
  try {
    return await invoke();
  } catch {
    return null;
  }
}

// A shell toggle's "on"/"off" reply as a boolean; null for anything else.
function onOff(reply: string | null): boolean | null {
  if (reply === "on") return true;
  if (reply === "off") return false;
  return null;
}

const pickTouchpad = (section: "mice" | "touch", name: string): boolean =>
  section === "mice" && /touchpad/i.test(name);
const pickTouchscreen = (section: "mice" | "touch", _name: string): boolean =>
  section === "touch";

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
    // hyprsunset runtime override, 4000K warm / 6500K neutral. No query
    // interface, so state rides the recorded override.
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
    // The top bar: the marchyo shell's bar when the shell is installed (the
    // shell keeps no queryable bar state, so --status reads the recorded
    // override), else waybar.service.
    name: "waybar",
    defaultOn: true,
    probe: async (capture) =>
      shellInstalled() ? null : unitActive(capture, "waybar.service"),
    flip: async () =>
      shellInstalled() ? onOff(await shellCall(() => shellIpc("toggleBar"))) : null,
    setOn: async (ctx) => {
      if (shellInstalled()) await shellCall(() => shellIpc("setBar", "on"));
      else await safeExec(ctx, systemctlUserArgv("start", "waybar.service"));
    },
    setOff: async (ctx) => {
      if (shellInstalled()) await shellCall(() => shellIpc("setBar", "off"));
      else await safeExec(ctx, systemctlUserArgv("stop", "waybar.service"));
    },
    revert: async (ctx) => {
      if (shellInstalled()) await shellCall(() => shellIpc("setBar", "on"));
      else await safeExec(ctx, systemctlUserArgv("start", "waybar.service"));
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
    // "off" = do-not-disturb. With the marchyo shell installed that is the
    // shell's DND (no queryable state, so --status reads the recorded
    // override); otherwise the mako mode from modules/home/mako.nix plus a
    // waybar indicator poke (SIGRTMIN+9).
    name: "notifications",
    defaultOn: true,
    probe: async (capture) => {
      if (shellInstalled()) return null;
      const r = await capture(makoctlArgv("mode"));
      if (r.code !== 0) return null;
      return !r.stdout.includes("do-not-disturb");
    },
    // toggleDnd replies with the DND state; notifications are on when it is off.
    flip: async () => {
      if (!shellInstalled()) return null;
      const dnd = onOff(await shellCall(() => shellIpc("toggleDnd")));
      return dnd === null ? null : !dnd;
    },
    setOn: async (ctx) => {
      if (shellInstalled()) {
        await shellCall(() => shellIpc("setDnd", "off"));
        return;
      }
      await safeExec(ctx, makoctlArgv("mode", "-r", "do-not-disturb"));
      await safeExec(ctx, ["pkill", "-SIGRTMIN+9", "waybar"]);
    },
    setOff: async (ctx) => {
      if (shellInstalled()) {
        await shellCall(() => shellIpc("setDnd", "on"));
        return;
      }
      await safeExec(ctx, makoctlArgv("mode", "-a", "do-not-disturb"));
      await safeExec(ctx, ["pkill", "-SIGRTMIN+9", "waybar"]);
    },
    revert: async (ctx) => {
      if (shellInstalled()) {
        await shellCall(() => shellIpc("setDnd", "off"));
        return;
      }
      await safeExec(ctx, makoctlArgv("mode", "-r", "do-not-disturb"));
      await safeExec(ctx, ["pkill", "-SIGRTMIN+9", "waybar"]);
    },
  },
  {
    // "off" = block sleep/idle via a tagged systemd inhibitor.
    name: "suspend",
    defaultOn: true,
    probe: async (capture) => {
      const r = await capture(["pgrep", "-f", probePattern(SUSPEND_INHIBIT_TAG)]);
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
    // "on" = caffeine: keep the machine awake. Stops hypridle (no lock, dim,
    // DPMS, screensaver, or idle-suspend) AND holds a tagged sleep:idle
    // inhibitor (blocks lid/logind/manual idle sleep). Distinct tag from the
    // `suspend` toggle so the two never collide.
    name: "caffeine",
    defaultOn: false,
    probe: async (capture) => {
      const r = await capture(["pgrep", "-f", probePattern(CAFFEINE_INHIBIT_TAG)]);
      return r.code === 0; // inhibitor present => caffeine on
    },
    setOn: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("stop", "hypridle.service"));
      try {
        const proc = Bun.spawn(
          [
            "systemd-inhibit",
            `--what=sleep:idle`,
            "--who=marchyo",
            `--why=${CAFFEINE_INHIBIT_TAG}`,
            "sleep",
            "infinity",
          ],
          { stdout: "ignore", stderr: "ignore", stdin: "ignore" },
        );
        proc.unref();
      } catch {
        // systemd-inhibit unavailable
      }
      if (!shellInstalled()) {
        await safeExec(ctx, ["pkill", "-SIGRTMIN+8", "waybar"]);
      }
      await notify(ctx, "Caffeine", "On — screen and sleep kept awake");
    },
    setOff: async (ctx) => {
      await safeExec(ctx, ["pkill", "-f", CAFFEINE_INHIBIT_TAG]);
      await safeExec(ctx, systemctlUserArgv("start", "hypridle.service"));
      if (!shellInstalled()) {
        await safeExec(ctx, ["pkill", "-SIGRTMIN+8", "waybar"]);
      }
      await notify(ctx, "Caffeine", "Off — normal idle behaviour restored");
    },
    revert: async (ctx) => {
      await safeExec(ctx, ["pkill", "-f", CAFFEINE_INHIBIT_TAG]);
      await safeExec(ctx, systemctlUserArgv("start", "hypridle.service"));
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
      if (typeof ctx.value !== "boolean" && def.flip) {
        const flipped = await def.flip();
        if (flipped !== null) return flipped;
      }
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
