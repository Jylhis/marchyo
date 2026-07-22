import type { Runtime } from "./runtime.ts";
import type { State } from "./state.ts";
import {
  SYSTEM_STATE_PATH,
  StateSchema,
  readState,
  userStatePath,
  writeState,
} from "./state.ts";
import {
  type OverrideValue,
  clearOverride,
  runtimeStatePath,
  setOverride,
} from "./runtime-state.ts";
import { runArgv } from "./system.ts";
import { detectFlake, nixosRebuild } from "./flake.ts";
import { err, hint, info, ok, usageError, warn } from "./output.ts";

// The F3.0 three-mode contract every mutating desktop command follows:
//   default (runtime) — apply live + persist an ephemeral override
//   --apply           — additionally persist to cli-state.json + rebuild
//   --revert          — undo: drop the override, restore the declarative
//                       value live, and delete + rebuild any persisted key
export type ChangeMode = "runtime" | "apply" | "revert";

export type ChangeContext = {
  rt: Runtime;
  // Exec seam; defaults to system.ts:runArgv, injected in tests.
  exec: (argv: string[]) => Promise<number>;
  // The requested value ("on"/"off"/a theme name); undefined = toggle/cycle.
  value: OverrideValue | undefined;
};

export type ChangeSpec = {
  // Dotted override key, e.g. "theme.selection", "toggle.nightlight".
  key: string;
  // Apply the change live; returns the value actually applied (recorded as
  // the runtime override so `marchyo runtime restore` can replay it).
  runtimeApply: (ctx: ChangeContext) => Promise<OverrideValue>;
  // Restore the declarative value live (the inverse of runtimeApply).
  runtimeRevert: (ctx: ChangeContext) => Promise<void>;
  // Persist the value into cli-state.json (--apply). Omitted = the change
  // is runtime-only and --apply is a usage error.
  stateWrite?: (prev: State, value: OverrideValue) => State;
  // Remove the persisted key from cli-state.json (--revert).
  stateDelete?: (prev: State) => State;
};

export type ChangeFlagOpts = { apply?: boolean; revert?: boolean };

// Resolve --apply/--revert into a mode; both at once is a usage error
// (returns 2, caller exits with it).
export function parseChangeFlags(
  rt: Runtime,
  opts: ChangeFlagOpts,
): ChangeMode | 2 {
  if (opts.apply && opts.revert) {
    return usageError(
      rt,
      "--apply and --revert are mutually exclusive",
      "pass one of them (or neither for a live-only change)",
    );
  }
  if (opts.apply) return "apply";
  if (opts.revert) return "revert";
  return "runtime";
}

export type ApplyChangeOptions = {
  mode: ChangeMode;
  value?: OverrideValue;
  // Test seams; every one defaults to the real implementation.
  exec?: (argv: string[]) => Promise<number>;
  runtimePath?: string;
  systemStatePath?: string;
  userPath?: string;
  stateWritePath?: string;
  rebuild?: (rt: Runtime) => Promise<number>;
};

// Default rebuild leg: detect the flake and run nixos-rebuild switch
// (--impure, sudo-wrapped). Mirrors commands/rebuild.ts behavior.
async function defaultRebuild(rt: Runtime): Promise<number> {
  const flake = await detectFlake();
  if (!flake) {
    err(rt, "no flake found (looked in cached state, /etc/nixos, cwd)");
    hint(rt, "Try: run from your flake directory once so marchyo can cache it");
    return 1;
  }
  info(rt, `rebuilding from ${flake.path} ...`);
  const result = await nixosRebuild({
    flakePath: flake.path,
    noInput: rt.noInput,
  });
  if (result.kind === "unavailable") {
    err(rt, result.message);
    return 1;
  }
  return result.code;
}

// Orchestrate one ChangeSpec through the selected mode. Returns an exit
// code (0 success, 1 runtime failure, 2 usage error).
export async function applyChange(
  rt: Runtime,
  spec: ChangeSpec,
  opts: ApplyChangeOptions,
): Promise<number> {
  const ctx: ChangeContext = {
    rt,
    exec: opts.exec ?? runArgv,
    value: opts.value,
  };
  const runtimePath = opts.runtimePath ?? runtimeStatePath();
  const rebuild = opts.rebuild ?? defaultRebuild;

  if (opts.mode === "runtime") {
    const applied = await spec.runtimeApply(ctx);
    await setOverride(spec.key, applied, runtimePath);
    ok(rt, `${spec.key} = ${JSON.stringify(applied)} (runtime)`);
    return 0;
  }

  if (opts.mode === "apply") {
    if (!spec.stateWrite) {
      return usageError(
        rt,
        `${spec.key} cannot be persisted with --apply`,
        "omit --apply for a live-only change",
      );
    }
    const applied = await spec.runtimeApply(ctx);
    // Record the override up front: if the rebuild below fails, the live
    // change still diverges from the declarative config and must survive
    // a `runtime restore`. Cleared only after a successful rebuild.
    await setOverride(spec.key, applied, runtimePath);
    const prev = await readState(
      opts.systemStatePath ?? SYSTEM_STATE_PATH,
      opts.userPath ?? userStatePath(),
    ).catch(() => ({}) as State);
    const next = StateSchema.parse(spec.stateWrite(prev, applied));
    const { path } = await writeState(
      next,
      opts.stateWritePath ? { path: opts.stateWritePath } : {},
    );
    ok(rt, `${spec.key} persisted to ${path}`);
    const code = await rebuild(rt);
    if (code !== 0) {
      warn(rt, "rebuild failed; the persisted value applies on next rebuild");
      return code;
    }
    // Declarative value now matches — the override would only go stale.
    await clearOverride(spec.key, runtimePath);
    return 0;
  }

  // mode === "revert"
  const hadOverride = await clearOverride(spec.key, runtimePath);
  await spec.runtimeRevert(ctx);
  if (hadOverride) ok(rt, `${spec.key} runtime override dropped`);

  if (spec.stateDelete) {
    const prev = await readState(
      opts.systemStatePath ?? SYSTEM_STATE_PATH,
      opts.userPath ?? userStatePath(),
    ).catch(() => ({}) as State);
    const next = StateSchema.parse(spec.stateDelete(prev));
    if (JSON.stringify(next) !== JSON.stringify(prev)) {
      const { path } = await writeState(
        next,
        opts.stateWritePath ? { path: opts.stateWritePath } : {},
      );
      ok(rt, `${spec.key} removed from ${path}`);
      return rebuild(rt);
    }
  }
  return 0;
}
