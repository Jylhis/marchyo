import { existsSync } from "node:fs";
import { rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import {
  type ChangeContext,
  type ChangeSpec,
  type State,
  captureArgv,
  hyprctlEvalArgv,
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
  tr,
} from "@marchyo/core";
import {
  clearReduceMotion,
  declarativeAppearance,
  fullscreenDesktopLua,
  reduceMotionState,
  reduceMotionStateDelete,
  reduceMotionStateWrite,
  setAnimations,
  setGaps,
  setReduceMotion,
  setTransparency,
} from "./commands/appearance.ts";

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
  // probe + setOn/setOff. One IPC round-trip instead of two, and the
  // recorded override is the state the shell reports, not the requested
  // one (the shell bar and do-not-disturb).
  flip?: () => Promise<boolean | null>;
  defaultOn: boolean;
  setOn: (ctx: ChangeContext) => Promise<void>;
  setOff: (ctx: ChangeContext) => Promise<void>;
  // Declarative default restore (runtimeRevert).
  revert: (ctx: ChangeContext) => Promise<void>;
  // Only hybrid-gpu is --apply-only; reduce-motion persists optionally and
  // everything else is runtime-only.
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

// Night light is on when hyprsunset runs warmer than the shell's 6000K
// identity point. A failed probe (hyprsunset not running) reads as off.
export function nightlightOnFrom(r: { code: number; stdout: string }): boolean {
  if (r.code !== 0) return false;
  const m = r.stdout.match(/[0-9]+/);
  return m !== null && Number.parseInt(m[0], 10) < 6000;
}

// Tell the shell the state hyprsunset actually reached, not the requested
// one: re-probe briefly until it matches `want`, then report what it reads.
async function reportNightlight(want: boolean, capture: Capture = captureArgv): Promise<void> {
  if (!shellInstalled()) return;
  let on = false;
  for (let i = 0; i < 5; i++) {
    on = nightlightOnFrom(await capture(["hyprctl", "hyprsunset", "temperature"]));
    if (on === want) break;
    await Bun.sleep(100);
  }
  await shellCall(() => shellIpc("nightlightChanged", on ? "on" : "off"));
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
    // "on" = spaced tiles (omarchy look); the declarative default is
    // marchyo.theme.appearance.gaps (the zero-gap tmux grid unless set).
    name: "gaps",
    defaultOn: false,
    probe: async (capture) => {
      const v = await getOptionFloat(capture, "general:gaps_out");
      return v === null ? null : v > 0;
    },
    setOn: (ctx) => setGaps(ctx, true),
    setOff: (ctx) => setGaps(ctx, false),
    revert: (ctx) => setGaps(ctx, declarativeAppearance().gaps),
  },
  {
    // "on" = transparent windows, "off" = opaque; the three-way choice is
    // `marchyo theme transparency`.
    name: "transparency",
    defaultOn: false,
    probe: async (capture) => {
      const v = await getOptionFloat(capture, "decoration:active_opacity");
      return v === null ? null : v < 1;
    },
    setOn: (ctx) => setTransparency(ctx, "transparent"),
    setOff: (ctx) => setTransparency(ctx, "opaque"),
    revert: (ctx) => setTransparency(ctx, declarativeAppearance().transparency),
  },
  {
    name: "animations",
    defaultOn: false,
    probe: async (capture) => {
      const v = await getOptionFloat(capture, "animations:enabled");
      return v === null ? null : v > 0;
    },
    setOn: (ctx) => setAnimations(ctx, true),
    setOff: (ctx) => setAnimations(ctx, false),
    revert: (ctx) => setAnimations(ctx, declarativeAppearance().animations),
  },
  {
    // "on" = the shell runs every transition at 0 ms. The shell watches its
    // style file (core shell-style.ts), so the toggle needs no IPC and
    // survives a shell restart. --apply persists
    // marchyo.theme.appearance.reduceMotion; --revert drops the style key so
    // the declarative value applies again.
    name: "reduce-motion",
    defaultOn: false,
    probe: async () => reduceMotionState(),
    setOn: () => setReduceMotion(true),
    setOff: () => setReduceMotion(false),
    revert: () => clearReduceMotion(),
    stateWrite: reduceMotionStateWrite,
    stateDelete: reduceMotionStateDelete,
  },
  {
    // Hide the bar and drop gaps, borders and rounding together.
    name: "fullscreen-desktop",
    defaultOn: false,
    probe: async (capture) => {
      const v = await getOptionFloat(capture, "general:border_size");
      return v === null ? null : v === 0;
    },
    setOn: async (ctx) => {
      await toggleByName("waybar")!.setOff(ctx);
      await safeExec(ctx, hyprctlEvalArgv(fullscreenDesktopLua(true)));
    },
    setOff: async (ctx) => {
      await toggleByName("waybar")!.setOn(ctx);
      await safeExec(ctx, hyprctlEvalArgv(fullscreenDesktopLua(false)));
    },
    revert: async (ctx) => {
      await toggleByName("waybar")!.revert(ctx);
      await safeExec(ctx, hyprctlEvalArgv(fullscreenDesktopLua(false)));
    },
  },
  {
    // 4000K warm / 6500K neutral over IPC to hyprsunset.service; starting a
    // second hyprsunset would take the CTM slot from the service.
    name: "nightlight",
    defaultOn: false,
    probe: async () => null,
    setOn: async (ctx) => {
      await safeExec(ctx, ["hyprctl", "hyprsunset", "temperature", "4000"]);
      await reportNightlight(true);
      await notify(ctx, tr("toggles.nightlight"), tr("toggles.on"));
    },
    setOff: async (ctx) => {
      await safeExec(ctx, ["hyprctl", "hyprsunset", "temperature", "6500"]);
      await reportNightlight(false);
      await notify(ctx, tr("toggles.nightlight"), tr("toggles.off"));
    },
    revert: async (ctx) => {
      await safeExec(ctx, ["hyprctl", "hyprsunset", "temperature", "6500"]);
      await reportNightlight(false);
    },
  },
  {
    // The top bar: the marchyo shell's bar when the shell is installed
    // (queried live over IPC; when the shell is not running the probe
    // falls back to the recorded override), else waybar.service.
    name: "waybar",
    defaultOn: true,
    probe: async (capture) =>
      shellInstalled()
        ? onOff(await shellCall(() => shellIpc("barState")))
        : unitActive(capture, "waybar.service"),
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
      await notify(ctx, tr("toggles.idleLock"), tr("toggles.enabled"));
    },
    setOff: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("stop", "hypridle.service"));
      await notify(ctx, tr("toggles.idleLock"), tr("toggles.disabledScreenWillStayAwake"));
    },
    revert: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("start", "hypridle.service"));
    },
  },
  {
    name: "crash-capture",
    defaultOn: true,
    probe: (capture) => unitActive(capture, "marchyo-crash-watch.service"),
    setOn: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("start", "marchyo-crash-watch.service"));
      await notify(ctx, tr("toggles.crashCapture"), tr("toggles.enabled"));
    },
    setOff: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("stop", "marchyo-crash-watch.service"));
      await notify(ctx, tr("toggles.crashCapture"), tr("toggles.crashCaptureOff"));
    },
    revert: async (ctx) => {
      await safeExec(ctx, systemctlUserArgv("start", "marchyo-crash-watch.service"));
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
    // shell's DND (queried live over IPC; when the shell is not running the
    // probe falls back to the recorded override); otherwise the mako mode
    // from modules/home/mako.nix plus a waybar indicator poke (SIGRTMIN+9).
    name: "notifications",
    defaultOn: true,
    probe: async (capture) => {
      if (shellInstalled()) {
        // dndState replies with the DND state; notifications are on when
        // it is off.
        const dnd = onOff(await shellCall(() => shellIpc("dndState")));
        return dnd === null ? null : !dnd;
      }
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
      await notify(ctx, tr("toggles.suspend"), tr("toggles.automaticSleepAllowed"));
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
      await notify(ctx, tr("toggles.suspend"), tr("toggles.automaticSleepInhibited"));
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
      if (shellInstalled()) {
        await shellCall(() => shellIpc("caffeineChanged", "on"));
      } else {
        await safeExec(ctx, ["pkill", "-SIGRTMIN+8", "waybar"]);
      }
      await notify(ctx, tr("toggles.caffeine"), tr("toggles.onScreenAndSleepKept"));
    },
    setOff: async (ctx) => {
      await safeExec(ctx, ["pkill", "-f", CAFFEINE_INHIBIT_TAG]);
      await safeExec(ctx, systemctlUserArgv("start", "hypridle.service"));
      if (shellInstalled()) {
        await shellCall(() => shellIpc("caffeineChanged", "off"));
      } else {
        await safeExec(ctx, ["pkill", "-SIGRTMIN+8", "waybar"]);
      }
      await notify(ctx, tr("toggles.caffeine"), tr("toggles.offNormalIdleBehaviourRestored"));
    },
    revert: async (ctx) => {
      await safeExec(ctx, ["pkill", "-f", CAFFEINE_INHIBIT_TAG]);
      await safeExec(ctx, systemctlUserArgv("start", "hypridle.service"));
      if (shellInstalled()) await shellCall(() => shellIpc("caffeineChanged", "off"));
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
