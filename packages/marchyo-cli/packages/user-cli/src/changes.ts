import type { ChangeSpec } from "@marchyo/core";
import { bgChangeBase, themeChangeBase } from "./commands/theme.ts";
import { fontChangeBase } from "./commands/font.ts";
import { TOGGLES, toggleSpecFor } from "./toggles.ts";

// Central ChangeSpec registry. Every mutating command group registers its
// specs here so `marchyo runtime restore` can rehydrate overrides after a
// session start (or a manual `hyprctl reload`) without duplicating the
// per-command runtime logic.
export const changeRegistry = new Map<string, ChangeSpec>();

export function registerChange(spec: ChangeSpec): void {
  changeRegistry.set(spec.key, spec);
}

registerChange(themeChangeBase);
registerChange(bgChangeBase);
registerChange(fontChangeBase);
for (const def of TOGGLES) registerChange(toggleSpecFor(def));
