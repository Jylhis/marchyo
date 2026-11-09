import { closeSync, mkdirSync, openSync, readFileSync, unlinkSync, writeSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { type Runtime, captureArgv, commandAvailable, data, err, usageError, tr } from "@marchyo/core";

// `marchyo dictation start|stop|toggle|status`: one verb over the dictation
// backend chosen by marchyo.dictation.backend (superwhisper | voxtype | hex).
// The backend is baked into $XDG_CONFIG_HOME/marchyo/dictation.json.

export type Backend = "superwhisper" | "voxtype" | "hex";
export type Action = "start" | "stop" | "toggle" | "status";
export type DictationState = "idle" | "recording" | "transcribing" | "stopped" | "unknown";

const BACKENDS: readonly Backend[] = ["superwhisper", "voxtype", "hex"];
const ACTIONS: readonly Action[] = ["start", "stop", "toggle", "status"];

// Hex control commands exit 3 when no Hex runs and 4 when the clip had no speech.
const HEX_NOT_RUNNING = 3;
const HEX_NO_SPEECH = 4;

export type Probe = { code: number; stdout: string };

export type DictationDeps = {
  backend: () => Backend | null;
  run: (argv: string[]) => Promise<Probe>;
  available: (cmd: string) => boolean;
  paste: (text: string) => Promise<void>;
  lockPath: string;
  lockWaitMs: number;
};

function configHome(): string {
  return process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
}

export function dictationConfigPath(): string {
  return join(configHome(), "marchyo", "dictation.json");
}

export function bakedBackend(path: string = dictationConfigPath()): Backend | null {
  try {
    const raw = JSON.parse(readFileSync(path, "utf8")) as { backend?: unknown };
    return BACKENDS.find((b) => b === raw.backend) ?? null;
  } catch {
    return null;
  }
}

async function pasteText(text: string): Promise<void> {
  const copy = Bun.spawn(["wl-copy"], { stdin: new Blob([text]), stdout: "ignore", stderr: "ignore" });
  await copy.exited;
  await Bun.sleep(150);
  await captureArgv(["wtype", text]);
}

function defaultDeps(): DictationDeps {
  const stateHome = process.env.XDG_STATE_HOME || join(homedir(), ".local", "state");
  return {
    backend: () => bakedBackend(),
    run: captureArgv,
    available: commandAvailable,
    paste: pasteText,
    lockPath: join(stateHome, "marchyo", "dictation.lock"),
    lockWaitMs: 5000,
  };
}

function pidAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function acquire(path: string, waitMs: number): Promise<(() => void) | null> {
  mkdirSync(dirname(path), { recursive: true });
  const deadline = Date.now() + waitMs;
  for (;;) {
    try {
      const fd = openSync(path, "wx");
      writeSync(fd, String(process.pid));
      closeSync(fd);
      return () => {
        try {
          unlinkSync(path);
        } catch {}
      };
    } catch {
      const holder = Number.parseInt(readFileOr(path), 10);
      if (Number.isFinite(holder) && !pidAlive(holder)) {
        try {
          unlinkSync(path);
        } catch {}
        continue;
      }
      if (Date.now() >= deadline) return null;
      await Bun.sleep(50);
    }
  }
}

function readFileOr(path: string): string {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

function parseJson(text: string): Record<string, unknown> | null {
  try {
    const v = JSON.parse(text);
    return typeof v === "object" && v !== null ? (v as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

function stateFromWord(word: unknown): DictationState {
  switch (word) {
    case "idle":
    case "ready":
      return "idle";
    case "recording":
    case "dictating":
      return "recording";
    case "transcribing":
    case "processing":
      return "transcribing";
    case "stopped":
      return "stopped";
    default:
      return "unknown";
  }
}

async function voxtypeState(deps: DictationDeps): Promise<DictationState> {
  const r = await deps.run(["voxtype", "status", "--format", "json"]);
  if (r.code !== 0) return "stopped";
  return stateFromWord(parseJson(r.stdout)?.class);
}

async function superwhisperState(deps: DictationDeps): Promise<DictationState> {
  const r = await deps.run(["superwhisper", "status"]);
  if (r.code !== 0) return "stopped";
  const o = parseJson(r.stdout);
  const phase = o?.phase ?? (o?.status as Record<string, unknown> | undefined)?.phase;
  return stateFromWord(phase);
}

async function hexState(deps: DictationDeps): Promise<DictationState> {
  const r = await deps.run(["hex", "status"]);
  if (r.code !== 0) return "stopped";
  const desktop = parseJson(r.stdout)?.desktop as { activity?: { state?: unknown } } | undefined;
  return stateFromWord(desktop?.activity?.state);
}

export function stateOf(backend: Backend, deps: DictationDeps): Promise<DictationState> {
  if (backend === "voxtype") return voxtypeState(deps);
  if (backend === "superwhisper") return superwhisperState(deps);
  return hexState(deps);
}

async function hexStart(deps: DictationDeps): Promise<number> {
  const first = await deps.run(["hex", "dictation", "start"]);
  if (first.code !== HEX_NOT_RUNNING) return first.code;
  const started = await deps.run(["hex", "start"]);
  if (started.code !== 0) return started.code;
  return (await deps.run(["hex", "dictation", "start"])).code;
}

// Hex pastes with a bare Ctrl+V, which terminals ignore, so take the
// transcript and type it into whatever is focused.
async function hexStop(deps: DictationDeps): Promise<number> {
  if ((await hexState(deps)) !== "recording") return 0;
  const r = await deps.run(["hex", "dictation", "stop", "--print"]);
  if (r.code === 0) {
    const text = r.stdout.replace(/\n+$/, "");
    if (text !== "") await deps.paste(text);
    return 0;
  }
  return r.code === HEX_NO_SPEECH ? 0 : r.code;
}

async function stopSuperwhisper(deps: DictationDeps): Promise<number> {
  const active = await deps.run(["systemctl", "--user", "is-active", "--quiet", "superwhisper.service"]);
  if (active.code !== 0) return 0;
  return (await deps.run(["superwhisper", "stop"])).code;
}

async function stopVoxtype(deps: DictationDeps): Promise<number> {
  if ((await voxtypeState(deps)) === "stopped") return 0;
  return (await deps.run(["voxtype", "record", "stop"])).code;
}

async function perform(backend: Backend, action: Exclude<Action, "status">, deps: DictationDeps): Promise<number> {
  switch (backend) {
    case "voxtype":
      if (action === "stop") return stopVoxtype(deps);
      return (await deps.run(["voxtype", "record", action])).code;
    case "superwhisper":
      if (action === "stop") return stopSuperwhisper(deps);
      return (await deps.run(["superwhisper", action === "start" ? "start" : "record"])).code;
    case "hex":
      if (action === "start") return hexStart(deps);
      if (action === "stop") return hexStop(deps);
      return (await hexState(deps)) === "recording" ? hexStop(deps) : hexStart(deps);
  }
}

export async function runDictation(
  rt: Runtime,
  action: string,
  deps: DictationDeps = defaultDeps(),
): Promise<number> {
  if (!ACTIONS.includes(action as Action)) {
    return usageError(rt, tr("dictation.unknownAction", action), "marchyo dictation <start|stop|toggle|status>");
  }
  const backend = deps.backend();
  if (backend === null) {
    err(rt, tr("dictation.noDictationBackendConfiguredSet"));
    return 1;
  }
  if (!deps.available(backend)) {
    err(rt, tr("dictation.theDictationBackendIsNot", backend));
    return 1;
  }
  if (action === "status") {
    const state = await stateOf(backend, deps);
    data(rt, { dictation: { backend, state } }, () => state);
    return 0;
  }
  const release = await acquire(deps.lockPath, deps.lockWaitMs);
  if (release === null) {
    err(rt, tr("dictation.dictationIsBusyTryAgain"));
    return 1;
  }
  try {
    const code = await perform(backend, action as Exclude<Action, "status">, deps);
    if (code !== 0) err(rt, tr("dictation.failedExit", backend, action, code));
    return code === 0 ? 0 : 1;
  } finally {
    release();
  }
}
