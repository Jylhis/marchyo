import {
  type Runtime,
  data,
  info,
  listOverrides,
  loadRuntimeState,
  ok,
  runArgv,
  runtimeStatePath,
  warn,
} from "@marchyo/core";
import { changeRegistry } from "../changes.ts";

// `marchyo runtime status` — list the active ephemeral overrides.
export async function runRuntimeStatus(rt: Runtime): Promise<number> {
  const state = await loadRuntimeState(runtimeStatePath(), (m) => warn(rt, m));
  const overrides = listOverrides(state);
  data(rt, { overrides }, () =>
    overrides.length === 0
      ? "(no runtime overrides)"
      : overrides
          .map(({ key, value }) => `${key} = ${JSON.stringify(value)}`)
          .join("\n"),
  );
  return 0;
}

// `marchyo runtime restore` — re-apply every stored override via its
// registered ChangeSpec. Idempotent and best-effort: unknown keys (an
// older CLI's overrides, or a spec that moved) warn and are skipped;
// a failing re-apply warns and continues so one bad actuator doesn't
// block the rest of the session's overrides.
export async function runRuntimeRestore(rt: Runtime): Promise<number> {
  const state = await loadRuntimeState(runtimeStatePath(), (m) => warn(rt, m));
  const overrides = listOverrides(state);
  if (overrides.length === 0) {
    info(rt, "no runtime overrides to restore");
    return 0;
  }
  let restored = 0;
  for (const { key, value } of overrides) {
    const spec = changeRegistry.get(key);
    if (!spec) {
      warn(rt, `no handler registered for override '${key}'; skipping`);
      continue;
    }
    try {
      await spec.runtimeApply({ rt, exec: runArgv, value });
      restored += 1;
    } catch (e) {
      warn(
        rt,
        `failed to restore '${key}': ${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }
  ok(rt, `restored ${restored}/${overrides.length} runtime override(s)`);
  return 0;
}
