import { existsSync, readFileSync, realpathSync } from "node:fs";
import { readdirSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import {
  type ChangeContext,
  type ChangeSpec,
  type Runtime,
  type State,
  type ThemeManifestEntry,
  THEME_ALIASES,
  applyChange,
  awwwImgArgv,
  currentThemePointerPath,
  data,
  declarativePointerPath,
  err,
  hint,
  hyprctlKeywordArgv,
  hyprlandAvailable,
  makoctlArgv,
  nextTheme,
  notifySendArgv,
  parseChangeFlags,
  pointCurrentTheme,
  readState,
  readThemeManifest,
  systemctlUserArgv,
  themeAtPointer,
  usageError,
  warn,
} from "@marchyo/core";
import { mkdir, symlink, rename } from "node:fs/promises";

// ---------------------------------------------------------------------------
// Actuation helpers (absorbed from modules/home/theme-runtime.nix's
// marchyo-theme-toggle — same commands, same || true tolerance)

async function safeExec(
  ctx: ChangeContext,
  argv: string[],
): Promise<void> {
  try {
    await ctx.exec(argv);
  } catch {
    // Missing binary / dead session: the switch continues best-effort.
  }
}

async function relinkConfig(target: string, linkPath: string): Promise<void> {
  await mkdir(dirname(linkPath), { recursive: true });
  const tmp = `${linkPath}.tmp-${process.pid}`;
  await symlink(target, tmp);
  await rename(tmp, linkPath);
}

function configHome(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_CONFIG_HOME;
  return xdg && xdg !== "" ? xdg : join(process.env.HOME ?? "~", ".config");
}

// Apply a theme dir's assets live. The reload vocabulary deliberately
// matches the absorbed shell script: awww for wallpaper, mako via symlink +
// makoctl reload, waybar via symlink + user-unit try-restart, Hyprland via
// per-keyword hyprctl (never `hyprctl reload`), low-urgency notify.
export async function activateThemeDir(
  ctx: ChangeContext,
  entry: ThemeManifestEntry,
): Promise<void> {
  await pointCurrentTheme(entry.dir);

  const wallpaper = join(entry.dir, "wallpaper.png");
  if (existsSync(wallpaper)) await safeExec(ctx, awwwImgArgv(wallpaper));

  const mako = join(entry.dir, "mako.conf");
  if (existsSync(mako)) {
    await relinkConfig(mako, join(configHome(), "mako", "config"));
    await safeExec(ctx, makoctlArgv("reload"));
  }

  const waybar = join(entry.dir, "waybar.css");
  if (existsSync(waybar)) {
    await relinkConfig(waybar, join(configHome(), "waybar", "style.css"));
    await safeExec(ctx, systemctlUserArgv("try-restart", "waybar.service"));
  }

  const hypr = join(entry.dir, "hyprland.conf");
  if (existsSync(hypr) && hyprlandAvailable()) {
    for (const line of readFileSync(hypr, "utf8").split("\n")) {
      const sp = line.indexOf(" ");
      if (sp <= 0) continue;
      await safeExec(
        ctx,
        hyprctlKeywordArgv(line.slice(0, sp), line.slice(sp + 1).trim()),
      );
    }
  }

  await safeExec(
    ctx,
    notifySendArgv("Theme", `Switched to ${entry.name}`),
  );
}

// The declarative default (what activation resets to): the HM profile's
// home-files copy of the pointer, matched against the manifest.
function declarativeTheme(
  manifest: ThemeManifestEntry[],
): ThemeManifestEntry | null {
  return themeAtPointer(manifest, declarativePointerPath());
}

// ---------------------------------------------------------------------------
// ChangeSpec — registered in changes.ts so `runtime restore` replays theme
// overrides; the persistence legs are attached per-invocation (they need
// the resolved manifest entry, and restore never uses them).

export const themeChangeBase: ChangeSpec = {
  key: "theme.selection",
  runtimeApply: async (ctx) => {
    const name = typeof ctx.value === "string" ? ctx.value : null;
    if (name === null) throw new Error("theme.selection needs a theme name");
    const manifest = await readThemeManifest();
    const entry = manifest.find((t) => t.name === name);
    if (!entry) throw new Error(`theme '${name}' not in the manifest`);
    await activateThemeDir(ctx, entry);
    return name;
  },
  runtimeRevert: async (ctx) => {
    const manifest = await readThemeManifest();
    const entry = declarativeTheme(manifest) ?? manifest[0] ?? null;
    if (entry) await activateThemeDir(ctx, entry);
  },
};

function themeSpecFor(entry: ThemeManifestEntry): ChangeSpec {
  return {
    ...themeChangeBase,
    stateWrite: (prev: State): State => ({
      ...prev,
      theme: entry.name.startsWith("jylhis-")
        ? { variant: entry.variant }
        : { variant: entry.variant, scheme: entry.name },
    }),
    stateDelete: (prev: State): State => {
      const next = { ...prev };
      delete next.theme;
      return next;
    },
  };
}

// ---------------------------------------------------------------------------
// Commands

export async function runThemeList(rt: Runtime): Promise<number> {
  const manifest = await readThemeManifest(undefined, (m) => warn(rt, m));
  if (manifest.length === 0) {
    err(rt, "no theme manifest found (is marchyo.desktop.enable set?)");
    return 1;
  }
  const current = themeAtPointer(manifest);
  data(
    rt,
    {
      themes: manifest.map((t) => ({
        name: t.name,
        variant: t.variant,
        current: t.name === (current?.name ?? null),
      })),
    },
    () =>
      manifest
        .map(
          (t) =>
            `${t.name === current?.name ? "*" : " "} ${t.name} (${t.variant})`,
        )
        .join("\n"),
  );
  return 0;
}

export async function runThemeGet(rt: Runtime): Promise<number> {
  const manifest = await readThemeManifest(undefined, (m) => warn(rt, m));
  const current = themeAtPointer(manifest);
  if (current) {
    data(rt, { theme: { name: current.name, variant: current.variant } }, () =>
      current.name,
    );
    return 0;
  }
  // Pre-manifest fallback: the persisted CLI state (old behavior).
  const state = await readState().catch(() => ({}) as State);
  const variant = state.theme?.variant ?? null;
  data(rt, { theme: { name: null, variant } }, () =>
    variant ?? "(unset, falling back to flake default)",
  );
  return 0;
}

export type ThemeSetOpts = {
  apply?: boolean;
  revert?: boolean;
  rebuild?: boolean;
};

async function setTheme(
  rt: Runtime,
  entry: ThemeManifestEntry,
  opts: ThemeSetOpts,
): Promise<number> {
  if (opts.rebuild) {
    warn(rt, "--rebuild is deprecated; use --apply (treated as --apply)");
  }
  const mode = parseChangeFlags(rt, {
    apply: (opts.apply ?? false) || (opts.rebuild ?? false),
    revert: opts.revert,
  });
  if (mode === 2) return 2;
  return applyChange(rt, themeSpecFor(entry), { mode, value: entry.name });
}

export async function runThemeSet(
  rt: Runtime,
  rawName: string,
  opts: ThemeSetOpts,
): Promise<number> {
  const name = THEME_ALIASES[rawName] ?? rawName;
  const manifest = await readThemeManifest(undefined, (m) => warn(rt, m));
  const entry = manifest.find((t) => t.name === name);
  if (!entry) {
    const known = manifest.map((t) => t.name).join(", ");
    return usageError(
      rt,
      `unknown theme: "${rawName}"`,
      manifest.length > 0
        ? `marchyo theme set <${known}>`
        : "enable marchyo.desktop and rebuild to generate the theme manifest",
    );
  }
  return setTheme(rt, entry, opts);
}

export async function runThemeNext(
  rt: Runtime,
  opts: ThemeSetOpts,
): Promise<number> {
  const manifest = await readThemeManifest(undefined, (m) => warn(rt, m));
  const entry = nextTheme(manifest, themeAtPointer(manifest));
  if (!entry) {
    err(rt, "no themes in the manifest");
    return 1;
  }
  return setTheme(rt, entry, opts);
}

// ---------------------------------------------------------------------------
// Wallpaper (`marchyo bg`) — runtime-only (the wallpaper package is
// declarative; there is no per-image persistence, so no --apply leg).

export const bgChangeBase: ChangeSpec = {
  key: "bg.image",
  runtimeApply: async (ctx) => {
    const image = typeof ctx.value === "string" ? ctx.value : null;
    if (image === null) throw new Error("bg.image needs an image path");
    await safeExec(ctx, awwwImgArgv(image));
    return image;
  },
  runtimeRevert: async (ctx) => {
    // Back to the active theme's own wallpaper.
    const wallpaper = join(currentThemePointerPath(), "wallpaper.png");
    if (existsSync(wallpaper)) await safeExec(ctx, awwwImgArgv(wallpaper));
  },
};

export type BgOpts = { revert?: boolean };

export async function runBgSet(
  rt: Runtime,
  rawPath: string,
  opts: BgOpts,
): Promise<number> {
  const mode = parseChangeFlags(rt, { revert: opts.revert });
  if (mode === 2) return 2;
  const image = isAbsolute(rawPath) ? rawPath : resolve(rawPath);
  if (mode !== "revert" && !existsSync(image)) {
    err(rt, `no such image: ${image}`);
    return 1;
  }
  return applyChange(rt, bgChangeBase, { mode, value: image });
}

export async function runBgNext(rt: Runtime): Promise<number> {
  // Cycle the images shipped next to the active theme's wallpaper (the
  // wallpaper package directory — jylhis-grid-{dark,light} by default,
  // more if the consumer swaps in a richer package).
  const current = join(currentThemePointerPath(), "wallpaper.png");
  if (!existsSync(current)) {
    err(rt, "no active theme wallpaper to cycle from");
    hint(rt, "Try: marchyo bg set <image>");
    return 1;
  }
  const real = realpathSync(current);
  const dir = dirname(real);
  const images = readdirSync(dir)
    .filter((f) => /\.(png|jpe?g|webp)$/i.test(f))
    .sort()
    .map((f) => join(dir, f));
  if (images.length === 0) {
    err(rt, `no images found in ${dir}`);
    return 1;
  }
  const idx = images.indexOf(real);
  const next = images[(idx + 1) % images.length]!;
  return applyChange(rt, bgChangeBase, { mode: "runtime", value: next });
}
