import { z } from "zod";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { mkdir, rename } from "node:fs/promises";

// Ephemeral runtime overrides (the F3.0 change model's "default = runtime"
// leg). Overrides survive `hyprctl reload` via `marchyo runtime restore`
// but deliberately NOT nixos-rebuild activation: activation rewrites the
// Home-Manager-managed surfaces (the theme-runtime contract), after which
// the declarative value is live again and stale overrides are meaningless.
// The file is INTERNAL (schema-versioned, may change between minors).
export const RUNTIME_SCHEMA_VERSION = 1;

// Override values are JSON primitives: toggles store booleans, selections
// (theme name, wallpaper index) store strings/numbers.
export const OverrideValue = z.union([
  z.string(),
  z.number(),
  z.boolean(),
  z.null(),
]);
export type OverrideValue = z.infer<typeof OverrideValue>;

export const RuntimeStateSchema = z
  .object({
    schemaVersion: z.number().int().positive(),
    overrides: z.record(z.string(), OverrideValue),
  })
  .strict();

export type RuntimeState = z.infer<typeof RuntimeStateSchema>;

export function emptyRuntimeState(): RuntimeState {
  return { schemaVersion: RUNTIME_SCHEMA_VERSION, overrides: {} };
}

export function runtimeStatePath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  return join(base, "marchyo", "runtime.json");
}

// Load the runtime state. The file is internal and ephemeral, so every
// failure mode degrades to "no overrides" instead of aborting the command:
// missing/empty file, invalid JSON, schema mismatch, or a newer
// schemaVersion (written by a newer CLI) all yield an empty state. `warn`
// receives a one-line diagnostic for the non-missing cases.
export async function loadRuntimeState(
  path: string = runtimeStatePath(),
  warn: (msg: string) => void = () => {},
): Promise<RuntimeState> {
  const file = Bun.file(path);
  if (!(await file.exists())) return emptyRuntimeState();
  let raw: string;
  try {
    raw = await file.text();
  } catch {
    return emptyRuntimeState();
  }
  if (raw.trim() === "") return emptyRuntimeState();
  let parsed: RuntimeState;
  try {
    parsed = RuntimeStateSchema.parse(JSON.parse(raw));
  } catch {
    warn(`ignoring invalid runtime state at ${path}`);
    return emptyRuntimeState();
  }
  if (parsed.schemaVersion > RUNTIME_SCHEMA_VERSION) {
    warn(
      `runtime state at ${path} has schema v${parsed.schemaVersion} (newer than this CLI); ignoring`,
    );
    return emptyRuntimeState();
  }
  return parsed;
}

// Atomic save: write a sibling temp file, then rename over the target so a
// crash mid-write never leaves a torn runtime.json for the next reader.
export async function saveRuntimeState(
  state: RuntimeState,
  path: string = runtimeStatePath(),
): Promise<void> {
  const validated = RuntimeStateSchema.parse(state);
  await mkdir(dirname(path), { recursive: true });
  const tmp = `${path}.tmp-${process.pid}`;
  await Bun.write(tmp, JSON.stringify(validated, null, 2) + "\n");
  await rename(tmp, path);
}

export async function setOverride(
  key: string,
  value: OverrideValue,
  path: string = runtimeStatePath(),
): Promise<RuntimeState> {
  const state = await loadRuntimeState(path);
  state.overrides[key] = value;
  await saveRuntimeState(state, path);
  return state;
}

// Remove an override. Returns true when the key existed.
export async function clearOverride(
  key: string,
  path: string = runtimeStatePath(),
): Promise<boolean> {
  const state = await loadRuntimeState(path);
  if (!(key in state.overrides)) return false;
  delete state.overrides[key];
  await saveRuntimeState(state, path);
  return true;
}

export function listOverrides(
  state: RuntimeState,
): Array<{ key: string; value: OverrideValue }> {
  return Object.entries(state.overrides)
    .map(([key, value]) => ({ key, value }))
    .sort((a, b) => a.key.localeCompare(b.key));
}
