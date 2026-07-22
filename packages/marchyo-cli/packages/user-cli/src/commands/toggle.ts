import {
  type Runtime,
  applyChange,
  data,
  parseChangeFlags,
  usageError,
} from "@marchyo/core";
import {
  TOGGLES,
  toggleByName,
  toggleSpecFor,
  toggleState,
} from "../toggles.ts";

export type ToggleOpts = {
  apply?: boolean;
  revert?: boolean;
  status?: boolean;
};

export async function runToggle(
  rt: Runtime,
  name: string,
  stateArg: string | undefined,
  opts: ToggleOpts,
): Promise<number> {
  const def = toggleByName(name);
  if (!def) {
    return usageError(
      rt,
      `unknown toggle: "${name}"`,
      `marchyo toggle <${TOGGLES.map((t) => t.name).join("|")}>`,
    );
  }

  if (opts.status) {
    const on = await toggleState(def);
    data(rt, { toggle: { name, on } }, () => (on ? "on" : "off"));
    return 0;
  }

  let value: boolean | undefined;
  if (stateArg !== undefined) {
    if (stateArg !== "on" && stateArg !== "off") {
      return usageError(
        rt,
        `invalid state: "${stateArg}"`,
        `marchyo toggle ${name} [on|off]`,
      );
    }
    value = stateArg === "on";
  }

  const mode = parseChangeFlags(rt, opts);
  if (mode === 2) return 2;
  if (def.applyOnly && mode === "runtime") {
    return usageError(
      rt,
      `${name} has no live toggle — it changes hardware configuration`,
      `marchyo toggle ${name} ${stateArg ?? "on"} --apply`,
    );
  }
  if (def.applyOnly && value === undefined && mode === "apply") {
    return usageError(
      rt,
      `${name} needs an explicit state with --apply`,
      `marchyo toggle ${name} on --apply`,
    );
  }

  return applyChange(rt, toggleSpecFor(def), { mode, value });
}
