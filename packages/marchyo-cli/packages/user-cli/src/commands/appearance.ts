import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  BAR_BACKGROUNDS,
  BAR_POSITIONS,
  ICON_THEME_KEY,
  type ChangeContext,
  type ChangeSpec,
  type Runtime,
  type State,
  applyChange,
  data,
  dconfResetArgv,
  dconfWriteArgv,
  gvariantString,
  hyprctlEvalArgv,
  hyprlandAvailable,
  parseChangeFlags,
  patchShellStyle,
  readShellStyle,
  usageError,
  tr,
} from "@marchyo/core";

// Window appearance: transparency and corners are enum selections, animations
// and gaps booleans. All of them go through `hyprctl eval`, the only live
// option path under Hyprland's Lua parser. `--revert` restores the
// declarative values modules/home/hyprland.nix writes to
// $XDG_CONFIG_HOME/marchyo/appearance.json. Shell-side style (reduce motion,
// bar position and background, UI font) goes to the shell style file instead
// (core shell-style.ts), which the shell watches.

export const TRANSPARENCY_MODES = ["opaque", "transparent", "glassy"] as const;
export const CORNER_MODES = ["theme", "sharp", "rounded"] as const;
export type TransparencyMode = (typeof TRANSPARENCY_MODES)[number];
export type CornerMode = (typeof CORNER_MODES)[number];

export type DeclarativeAppearance = {
  transparency: TransparencyMode;
  corners: CornerMode;
  animations: boolean;
  shellGlass: boolean;
  gaps: boolean;
  reduceMotion: boolean;
  // gtk.iconTheme.name, or null when the host declares none.
  iconTheme: string | null;
};

const FALLBACK: DeclarativeAppearance = {
  transparency: "opaque",
  corners: "theme",
  animations: false,
  shellGlass: false,
  gaps: false,
  reduceMotion: false,
  iconTheme: null,
};

export function appearancePath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_CONFIG_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".config");
  return join(base, "marchyo", "appearance.json");
}

export function declarativeAppearance(
  path: string = appearancePath(),
): DeclarativeAppearance {
  if (!existsSync(path)) return FALLBACK;
  try {
    const raw = JSON.parse(readFileSync(path, "utf8")) as Partial<
      Record<keyof DeclarativeAppearance, unknown>
    >;
    return {
      transparency: TRANSPARENCY_MODES.includes(raw.transparency as never)
        ? (raw.transparency as TransparencyMode)
        : FALLBACK.transparency,
      corners: CORNER_MODES.includes(raw.corners as never)
        ? (raw.corners as CornerMode)
        : FALLBACK.corners,
      animations:
        typeof raw.animations === "boolean" ? raw.animations : FALLBACK.animations,
      shellGlass:
        typeof raw.shellGlass === "boolean" ? raw.shellGlass : FALLBACK.shellGlass,
      gaps: typeof raw.gaps === "boolean" ? raw.gaps : FALLBACK.gaps,
      reduceMotion:
        typeof raw.reduceMotion === "boolean" ? raw.reduceMotion : FALLBACK.reduceMotion,
      iconTheme:
        typeof raw.iconTheme === "string" && raw.iconTheme !== ""
          ? raw.iconTheme
          : FALLBACK.iconTheme,
    };
  } catch {
    return FALLBACK;
  }
}

export function transparencyLua(mode: TransparencyMode, shellGlass: boolean): string {
  const opacity =
    mode === "opaque"
      ? "active_opacity = 1.0, inactive_opacity = 1.0"
      : "active_opacity = 0.92, inactive_opacity = 0.85";
  const blur = mode === "glassy" || shellGlass;
  return `hl.config({ decoration = { ${opacity}, blur = { enabled = ${blur} } } })`;
}

export function cornersLua(mode: CornerMode): string {
  return mode === "rounded"
    ? "hl.config({ decoration = { rounding = 6, rounding_power = 3 } })"
    : "hl.config({ decoration = { rounding = 0 } })";
}

export function animationsLua(on: boolean): string {
  return `hl.config({ animations = { enabled = ${on} } })`;
}

export function gapsLua(on: boolean): string {
  return on
    ? "hl.config({ general = { gaps_in = 5, gaps_out = 10 } })"
    : "hl.config({ general = { gaps_in = 0, gaps_out = 0 } })";
}

// On: no gaps, borders or rounding. Off: the declarative 2px border, corners
// and gaps.
export function fullscreenDesktopLua(
  on: boolean,
  corners: CornerMode = declarativeAppearance().corners,
  gaps: boolean = declarativeAppearance().gaps,
): string {
  if (on) {
    return "hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 0 }, decoration = { rounding = 0 } })";
  }
  const rounding = corners === "rounded" ? 6 : 0;
  const [gapsIn, gapsOut] = gaps ? [5, 10] : [0, 0];
  return `hl.config({ general = { gaps_in = ${gapsIn}, gaps_out = ${gapsOut}, border_size = 2 }, decoration = { rounding = ${rounding} } })`;
}

async function evalLua(ctx: ChangeContext, code: string): Promise<void> {
  if (!hyprlandAvailable()) return;
  try {
    await ctx.exec(hyprctlEvalArgv(code));
  } catch {
    // best-effort actuation
  }
}

export function setTransparency(
  ctx: ChangeContext,
  mode: TransparencyMode,
): Promise<void> {
  return evalLua(ctx, transparencyLua(mode, declarativeAppearance().shellGlass));
}

export function setAnimations(ctx: ChangeContext, on: boolean): Promise<void> {
  return evalLua(ctx, animationsLua(on));
}

export function setGaps(ctx: ChangeContext, on: boolean): Promise<void> {
  return evalLua(ctx, gapsLua(on));
}

export const transparencyChangeBase: ChangeSpec = {
  key: "appearance.transparency",
  runtimeApply: async (ctx) => {
    const mode = ctx.value;
    if (!TRANSPARENCY_MODES.includes(mode as never)) {
      throw new Error(
        `appearance.transparency needs one of ${TRANSPARENCY_MODES.join("|")}`,
      );
    }
    await setTransparency(ctx, mode as TransparencyMode);
    return mode as TransparencyMode;
  },
  runtimeRevert: (ctx) => setTransparency(ctx, declarativeAppearance().transparency),
};

export const cornersChangeBase: ChangeSpec = {
  key: "appearance.corners",
  runtimeApply: async (ctx) => {
    const mode = ctx.value;
    if (!CORNER_MODES.includes(mode as never)) {
      throw new Error(`appearance.corners needs one of ${CORNER_MODES.join("|")}`);
    }
    await evalLua(ctx, cornersLua(mode as CornerMode));
    return mode as CornerMode;
  },
  runtimeRevert: (ctx) => evalLua(ctx, cornersLua(declarativeAppearance().corners)),
};

function onOffValue(value: unknown, what: string): boolean {
  if (typeof value === "boolean") return value;
  if (value === "on") return true;
  if (value === "off") return false;
  throw new Error(`${what} needs on or off`);
}

// Window gaps as a persistable choice (`marchyo theme gaps`). --apply writes
// marchyo.theme.appearance.gaps; the `gaps` toggle stays runtime-only.
export const gapsChangeBase: ChangeSpec = {
  key: "appearance.gaps",
  runtimeApply: async (ctx) => {
    const on = onOffValue(ctx.value, "appearance.gaps");
    await setGaps(ctx, on);
    return on;
  },
  runtimeRevert: (ctx) => setGaps(ctx, declarativeAppearance().gaps),
  stateWrite: (prev: State, value) => ({
    ...prev,
    theme: {
      ...prev.theme,
      appearance: { ...prev.theme?.appearance, gaps: value === true },
    },
  }),
  stateDelete: (prev: State) => dropThemeAppearance(prev, "gaps"),
};

export function dropThemeAppearance(
  prev: State,
  key: "gaps" | "reduceMotion",
): State {
  if (prev.theme?.appearance?.[key] === undefined) return prev;
  const { [key]: _dropped, ...appearance } = prev.theme.appearance;
  const theme = { ...prev.theme };
  if (Object.keys(appearance).length > 0) theme.appearance = appearance;
  else delete theme.appearance;
  const next = { ...prev };
  if (Object.keys(theme).length > 0) next.theme = theme;
  else delete next.theme;
  return next;
}

// Reduce motion: the shell reads it from the style file; the eval-time
// marchyo.theme.appearance.reduceMotion option (appearance.json) is the
// default an absent key means.
export function reduceMotionState(): boolean {
  return readShellStyle().reduceMotion ?? declarativeAppearance().reduceMotion;
}

export async function setReduceMotion(on: boolean): Promise<void> {
  await patchShellStyle({ reduceMotion: on });
}

export async function clearReduceMotion(): Promise<void> {
  await patchShellStyle({ reduceMotion: null });
}

export function reduceMotionStateWrite(prev: State, on: boolean): State {
  return {
    ...prev,
    theme: {
      ...prev.theme,
      appearance: { ...prev.theme?.appearance, reduceMotion: on },
    },
  };
}

export function reduceMotionStateDelete(prev: State): State {
  return dropThemeAppearance(prev, "reduceMotion");
}

function choiceSpec<T extends string>(
  key: string,
  modes: readonly T[],
  styleKey: "barPosition" | "barBackground",
): ChangeSpec {
  return {
    key,
    runtimeApply: async (ctx) => {
      if (!modes.includes(ctx.value as T)) {
        throw new Error(`${key} needs one of ${modes.join("|")}`);
      }
      await patchShellStyle({ [styleKey]: ctx.value as T });
      return ctx.value as T;
    },
    runtimeRevert: async () => {
      await patchShellStyle({ [styleKey]: null });
    },
  };
}

export const barPositionChangeBase = choiceSpec(
  "appearance.barPosition",
  BAR_POSITIONS,
  "barPosition",
);

export const barBackgroundChangeBase = choiceSpec(
  "appearance.barBackground",
  BAR_BACKGROUNDS,
  "barBackground",
);

// Icon theme names found in the XDG icon dirs: a directory with an
// index.theme that declares Directories (cursor-only themes do not).
export function iconThemeDirs(env: NodeJS.ProcessEnv = process.env): string[] {
  const dataHome =
    env.XDG_DATA_HOME && env.XDG_DATA_HOME !== ""
      ? env.XDG_DATA_HOME
      : join(homedir(), ".local", "share");
  const dataDirs = (env.XDG_DATA_DIRS ?? "/usr/local/share:/usr/share")
    .split(":")
    .filter((d) => d !== "");
  return [
    join(dataHome, "icons"),
    join(homedir(), ".icons"),
    ...dataDirs.map((d) => join(d, "icons")),
  ];
}

export function installedIconThemes(dirs: string[] = iconThemeDirs()): string[] {
  const names = new Set<string>();
  for (const dir of dirs) {
    let entries: string[];
    try {
      entries = readdirSync(dir);
    } catch {
      continue;
    }
    for (const name of entries) {
      try {
        const index = readFileSync(join(dir, name, "index.theme"), "utf8");
        if (/^Directories\s*=/m.test(index) && !/^Hidden\s*=\s*true/im.test(index)) {
          names.add(name);
        }
      } catch {
        // not an icon theme directory
      }
    }
  }
  return [...names].sort((a, b) => a.localeCompare(b));
}

export async function setIconTheme(ctx: ChangeContext, name: string): Promise<void> {
  try {
    await ctx.exec(dconfWriteArgv(ICON_THEME_KEY, gvariantString(name)));
  } catch {
    // best-effort actuation
  }
}

export const iconThemeChangeBase: ChangeSpec = {
  key: "appearance.iconTheme",
  runtimeApply: async (ctx) => {
    if (typeof ctx.value !== "string" || ctx.value === "") {
      throw new Error("appearance.iconTheme needs an icon theme name");
    }
    await setIconTheme(ctx, ctx.value);
    return ctx.value;
  },
  runtimeRevert: async (ctx) => {
    const declared = declarativeAppearance().iconTheme;
    if (declared !== null) {
      await setIconTheme(ctx, declared);
      return;
    }
    try {
      await ctx.exec(dconfResetArgv(ICON_THEME_KEY));
    } catch {
      // best-effort actuation
    }
  },
};

export type AppearanceOpts = { revert?: boolean };

async function runChoice(
  rt: Runtime,
  spec: ChangeSpec,
  name: string,
  modes: readonly string[],
  declared: string,
  value: string | undefined,
  opts: AppearanceOpts,
): Promise<number> {
  const mode = parseChangeFlags(rt, { revert: opts.revert });
  if (mode === 2) return 2;
  if (mode === "revert") return applyChange(rt, spec, { mode });
  if (value === undefined) {
    data(rt, { [name]: { declarative: declared, modes: [...modes] } }, () =>
      modes.join("\n"),
    );
    return 0;
  }
  if (!modes.includes(value)) {
    return usageError(
      rt,
      tr("appearance.invalidMode", name, value),
      `marchyo theme ${name} <${modes.join("|")}>`,
    );
  }
  return applyChange(rt, spec, { mode, value });
}

export function runThemeTransparency(
  rt: Runtime,
  value: string | undefined,
  opts: AppearanceOpts,
): Promise<number> {
  return runChoice(
    rt,
    transparencyChangeBase,
    "transparency",
    TRANSPARENCY_MODES,
    declarativeAppearance().transparency,
    value,
    opts,
  );
}

export function runThemeCorners(
  rt: Runtime,
  value: string | undefined,
  opts: AppearanceOpts,
): Promise<number> {
  return runChoice(
    rt,
    cornersChangeBase,
    "corners",
    CORNER_MODES,
    declarativeAppearance().corners,
    value,
    opts,
  );
}

export async function runThemeGaps(
  rt: Runtime,
  value: string | undefined,
  opts: AppearanceOpts & { apply?: boolean },
): Promise<number> {
  const mode = parseChangeFlags(rt, opts);
  if (mode === 2) return 2;
  if (mode === "revert") return applyChange(rt, gapsChangeBase, { mode });
  if (value === undefined) {
    data(
      rt,
      { gaps: { declarative: declarativeAppearance().gaps, modes: ["on", "off"] } },
      () => "on\noff",
    );
    return 0;
  }
  if (value !== "on" && value !== "off") {
    return usageError(
      rt,
      tr("appearance.invalidMode", "gaps", value),
      "marchyo theme gaps <on|off>",
    );
  }
  return applyChange(rt, gapsChangeBase, { mode, value: value === "on" });
}

export function runThemeBarPosition(
  rt: Runtime,
  value: string | undefined,
  opts: AppearanceOpts,
): Promise<number> {
  return runChoice(
    rt,
    barPositionChangeBase,
    "bar-position",
    BAR_POSITIONS,
    "top",
    value,
    opts,
  );
}

export function runThemeBarBackground(
  rt: Runtime,
  value: string | undefined,
  opts: AppearanceOpts,
): Promise<number> {
  return runChoice(
    rt,
    barBackgroundChangeBase,
    "bar-background",
    BAR_BACKGROUNDS,
    "opaque",
    value,
    opts,
  );
}

export async function runThemeIcons(
  rt: Runtime,
  name: string | undefined,
  opts: AppearanceOpts,
): Promise<number> {
  const mode = parseChangeFlags(rt, opts);
  if (mode === 2) return 2;
  if (mode === "revert") return applyChange(rt, iconThemeChangeBase, { mode });
  const installed = installedIconThemes();
  if (name === undefined || name === "") {
    data(
      rt,
      { icons: { declarative: declarativeAppearance().iconTheme, themes: installed } },
      () => installed.join("\n"),
    );
    return 0;
  }
  if (!installed.includes(name)) {
    return usageError(
      rt,
      tr("appearance.unknownIconTheme", name),
      "marchyo theme icons   (lists the installed icon themes)",
    );
  }
  return applyChange(rt, iconThemeChangeBase, { mode, value: name });
}
