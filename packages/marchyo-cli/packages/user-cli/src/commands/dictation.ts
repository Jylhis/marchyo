import { closeSync, mkdirSync, openSync, readFileSync, unlinkSync, writeSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { type Runtime, captureArgv, commandAvailable, data, err, usageError, tr } from "@marchyo/core";

// `marchyo dictation start|stop|toggle|status`: one verb over the dictation
// backend chosen by marchyo.dictation.backend (voxtype).
// The backend is baked into $XDG_CONFIG_HOME/marchyo/dictation.json.

export type Backend = "voxtype";
export type Action = "start" | "stop" | "toggle" | "status";
export type DictationState = "idle" | "recording" | "transcribing" | "stopped" | "unknown";

const BACKENDS: readonly Backend[] = ["voxtype"];
const ACTIONS: readonly Action[] = ["start", "stop", "toggle", "status"];

export type Probe = { code: number; stdout: string };

export type DictationDeps = {
  backend: () => Backend | null;
  run: (argv: string[]) => Promise<Probe>;
  available: (cmd: string) => boolean;
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

function defaultDeps(): DictationDeps {
  const stateHome = process.env.XDG_STATE_HOME || join(homedir(), ".local", "state");
  return {
    backend: () => bakedBackend(),
    run: captureArgv,
    available: commandAvailable,
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

export function stateOf(_backend: Backend, deps: DictationDeps): Promise<DictationState> {
  return voxtypeState(deps);
}

async function stopVoxtype(deps: DictationDeps): Promise<number> {
  if ((await voxtypeState(deps)) === "stopped") return 0;
  return (await deps.run(["voxtype", "record", "stop"])).code;
}

async function perform(_backend: Backend, action: Exclude<Action, "status">, deps: DictationDeps): Promise<number> {
  if (action === "stop") return stopVoxtype(deps);
  return (await deps.run(["voxtype", "record", action])).code;
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
