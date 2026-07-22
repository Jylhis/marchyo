import type { ChangeSpec } from "@marchyo/core";

// Central ChangeSpec registry. Every mutating command group registers its
// specs here so `marchyo runtime restore` can rehydrate overrides after a
// session start (or a manual `hyprctl reload`) without duplicating the
// per-command runtime logic. Theme registers in the theme-CLI slice;
// toggles in the toggles slice.
export const changeRegistry = new Map<string, ChangeSpec>();

export function registerChange(spec: ChangeSpec): void {
  changeRegistry.set(spec.key, spec);
}
