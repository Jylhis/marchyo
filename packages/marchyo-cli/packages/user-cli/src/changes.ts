import type { ChangeSpec } from "@marchyo/core";
import {
  bgChangeBase,
  generateThemeChangeBase,
  themeChangeBase,
} from "./commands/theme.ts";
import { fontChangeBase, uiFontChangeBase } from "./commands/font.ts";
import { languageChangeBase } from "./commands/language.ts";
import {
  barBackgroundChangeBase,
  barPositionChangeBase,
  cornersChangeBase,
  gapsChangeBase,
  iconThemeChangeBase,
  transparencyChangeBase,
} from "./commands/appearance.ts";
import { barLayoutChangeBase } from "./commands/bar.ts";
import { TOGGLES, toggleSpecFor } from "./toggles.ts";

// Central ChangeSpec registry. Every mutating command group registers its
// specs here so `marchyo runtime restore` can rehydrate overrides after a
// session start, a home-manager activation or a manual `hyprctl reload`
// without duplicating the per-command runtime logic.
export const changeRegistry = new Map<string, ChangeSpec>();

export function registerChange(spec: ChangeSpec): void {
  changeRegistry.set(spec.key, spec);
}

registerChange(themeChangeBase);
registerChange(bgChangeBase);
registerChange(generateThemeChangeBase);
registerChange(fontChangeBase);
registerChange(uiFontChangeBase);
registerChange(languageChangeBase);
registerChange(transparencyChangeBase);
registerChange(cornersChangeBase);
registerChange(gapsChangeBase);
registerChange(barPositionChangeBase);
registerChange(barBackgroundChangeBase);
registerChange(iconThemeChangeBase);
registerChange(barLayoutChangeBase);
for (const def of TOGGLES) registerChange(toggleSpecFor(def));
