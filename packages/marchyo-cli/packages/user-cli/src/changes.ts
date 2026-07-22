import type { ChangeSpec } from "@marchyo/core";
import { bgChangeBase, themeChangeBase } from "./commands/theme.ts";

// Central ChangeSpec registry. Every mutating command group registers its
// specs here so `marchyo runtime restore` can rehydrate overrides after a
// session start (or a manual `hyprctl reload`) without duplicating the
// per-command runtime logic. Toggles register in the toggles slice.
export const changeRegistry = new Map<string, ChangeSpec>();

export function registerChange(spec: ChangeSpec): void {
  changeRegistry.set(spec.key, spec);
}

registerChange(themeChangeBase);
registerChange(bgChangeBase);
