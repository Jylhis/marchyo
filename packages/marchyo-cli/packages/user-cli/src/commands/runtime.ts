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
  tr,
} from "@marchyo/core";
import { changeRegistry } from "../changes.ts";
import { restoreEffectiveTheme } from "./theme.ts";

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

// Replay order: the theme first (activating a theme sets its wallpaper), then
// the wallpaper, fonts, appearance, toggles and anything else.
const RESTORE_ORDER = [
  "theme.",
  "bg.",
  "font.",
  "appearance.",
  "toggle.",
] as const;

export function restoreRank(key: string): number {
  const i = RESTORE_ORDER.findIndex((prefix) => key.startsWith(prefix));
  return i === -1 ? RESTORE_ORDER.length : i;
}

export function restoreOrder<T extends { key: string }>(overrides: T[]): T[] {
  return [...overrides].sort(
    (a, b) =>
      restoreRank(a.key) - restoreRank(b.key) || a.key.localeCompare(b.key),
  );
}

export async function runRuntimeRestore(rt: Runtime): Promise<number> {
  const state = await loadRuntimeState(runtimeStatePath(), (m) => warn(rt, m));
  const all = listOverrides(state);
  const themeKeys = new Set(["theme.selection", "theme.generate"]);
  const overrides = restoreOrder(all.filter(({ key }) => !themeKeys.has(key)));
  let total = all.length;
  let restored = 0;
  let failed = false;
  try {
    const applied = await restoreEffectiveTheme(
      { rt, exec: runArgv, value: undefined },
      state.overrides,
    );
    if (applied) {
      restored += 1;
      if (!all.some(({ key }) => themeKeys.has(key))) total += 1;
    }
  } catch (e) {
    failed = true;
    if (!all.some(({ key }) => themeKeys.has(key))) total += 1;
    warn(
      rt,
      tr(
        "runtime.failedToRestore",
        "theme",
        e instanceof Error ? e.message : String(e),
      ),
    );
  }
  if (total === 0) {
    info(rt, tr("runtime.noRuntimeOverridesToRestore"));
    return 0;
  }
  for (const { key, value } of overrides) {
    const spec = changeRegistry.get(key);
    if (!spec) {
      warn(rt, tr("runtime.noHandlerRegisteredForOverride", key));
      failed = true;
      continue;
    }
    try {
      await spec.runtimeApply({ rt, exec: runArgv, value });
      restored += 1;
    } catch (e) {
      failed = true;
      warn(
        rt,
        tr(
          "runtime.failedToRestore",
          key,
          e instanceof Error ? e.message : String(e),
        ),
      );
    }
  }
  const report = failed ? warn : ok;
  report(rt, tr("runtime.restoredRuntimeOverride", restored, total));
  return failed ? 1 : 0;
}
