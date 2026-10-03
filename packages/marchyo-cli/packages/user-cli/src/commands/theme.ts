import { existsSync, readFileSync, realpathSync } from "node:fs";
import { readdirSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import {
  type ChangeContext,
  type ChangeSpec,
  type Runtime,
  type State,
  type ThemeManifestEntry,
  COLOR_SCHEME_KEY,
  THEME_ALIASES,
  applyChange,
  awwwImgArgv,
  captureArgv,
  colorSchemeGvariant,
  currentThemePointerPath,
  data,
  dconfWriteArgv,
  declarativePointerPath,
  err,
  fzfOptsFromBase16,
  ghosttyConfFromBase16,
  hint,
  hyprctlEvalArgv,
  hyprlandAvailable,
  hyprlandConfFromBase16,
  makoctlArgv,
  matugenArgv,
  ColorsJson as ColorsJsonSchema,
  detectVariant,
  generatedThemeDirPath,
  parseMatugenBase16,
  recolorShellColors,
  nextTheme,
  notifySendArgv,
  parseChangeFlags,
  pointCurrentTheme,
  readState,
  setvtrgbArgv,
  readThemeManifest,
  systemctlUserArgv,
  themeAtPointer,
  usageError,
  warn,
} from "@marchyo/core";
import type { Variant } from "@marchyo/core";
import { mkdir, symlink, rename, writeFile } from "node:fs/promises";

// Actuation helpers mirroring modules/home/theme-runtime.nix: same commands,
// same || true tolerance.

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

// Hyprland: the theme dir ships a hyprlang-style keyword list
// (`section:subkey value` per line, see theme-runtime.nix's
// hyprlandKeywordsFor). `hyprctl keyword` is a no-op under non-legacy
// (Lua) parsers, so the lines are grouped into one nested table and applied
// through the parse-time-equivalent `hl.config` call via `hyprctl eval`.
// Values are rgb()/rgba() literals (no quotes or backslashes — verified
// against theme-runtime.nix's generators), so plain double-quoted Lua
// strings suffice; the section/subkey keys stay bracket-quoted because of
// their dots.
export function hyprlandConfigTable(
  confText: string,
): Record<string, Record<string, string>> {
  const table: Record<string, Record<string, string>> = {};
  for (const line of confText.split("\n")) {
    const sp = line.indexOf(" ");
    if (sp <= 0) continue;
    const key = line.slice(0, sp);
    const colon = key.indexOf(":");
    if (colon <= 0) continue;
    const section = key.slice(0, colon);
    const subkey = key.slice(colon + 1);
    const value = line.slice(sp + 1).trim();
    (table[section] ??= {})[subkey] = value;
  }
  return table;
}

export function hyprlandConfigLua(
  table: Record<string, Record<string, string>>,
): string {
  const sections = Object.entries(table).map(([section, subkeys]) => {
    const pairs = Object.entries(subkeys).map(
      ([subkey, value]) => `["${subkey}"] = "${value}"`,
    );
    return `["${section}"] = { ${pairs.join(", ")} }`;
  });
  return `hl.config({ ${sections.join(", ")} })`;
}

// Apply a theme dir's assets live. The reload vocabulary deliberately
// matches theme-runtime.nix's shell script: awww for wallpaper, mako via symlink +
// makoctl reload, waybar via symlink + user-unit try-restart, Hyprland via
// `hyprctl eval hl.config(...)` (never `hyprctl keyword`, a no-op under
// non-legacy parsers, nor `hyprctl reload`, which re-reads the build-time
// config), low-urgency notify.
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
    const table = hyprlandConfigTable(readFileSync(hypr, "utf8"));
    if (Object.keys(table).length > 0) {
      await safeExec(ctx, hyprctlEvalArgv(hyprlandConfigLua(table)));
    }
  }

  // GTK: relink the user css for both major versions (HM-managed symlinks
  // until the next activation restores them) and flip the dconf color-scheme
  // so libadwaita apps restyle live. Newly launched GTK apps read the
  // swapped css; running GTK3 apps keep their cached style context. Gated
  // on the theme carrying GTK assets, so headless hosts and test fixtures
  // never touch a real dconf session.
  const gtk = join(entry.dir, "gtk.css");
  if (existsSync(gtk)) {
    await relinkConfig(gtk, join(configHome(), "gtk-3.0", "gtk.css"));
    await relinkConfig(gtk, join(configHome(), "gtk-4.0", "gtk.css"));
    await safeExec(
      ctx,
      dconfWriteArgv(COLOR_SCHEME_KEY, colorSchemeGvariant(entry.variant)),
    );
  }

  // bat: relink the per-theme config (a `--theme=<name>` line swap, see
  // theme-runtime.nix). No reload signal: bat is a fresh process per run, so
  // the next invocation reads the swapped config. The theme's tmTheme is
  // already in bat's build-time cache (the Jylhis pair ships it; scheme themes
  // are registered via programs.bat.themes), so this is a pure name swap.
  const bat = join(entry.dir, "bat.conf");
  if (existsSync(bat)) {
    await relinkConfig(bat, join(configHome(), "bat", "config"));
  }

  // console/TTY: best-effort only. setvtrgb repaints the live VT palette, but a
  // Wayland-session process has no controlling console, so this usually no-ops
  // and the TTY instead tracks the declarative console.colors at the next boot
  // (modules/nixos/console.nix). safeExec swallows the missing-binary / not-a-
  // console failure, matching the emit-and-accept-next-boot contract.
  const consoleTable = join(entry.dir, "console.txt");
  if (existsSync(consoleTable)) await safeExec(ctx, setvtrgbArgv(consoleTable));

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
  // Pre-manifest fallback: the persisted CLI state.
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
  // The positional is optional (it is omitted with --revert), and the action
  // passes "" when it is missing. Without this guard resolve("") returns the
  // cwd, existsSync(cwd) is always true, and the cwd got persisted into
  // runtime.json as the wallpaper. Same shape as `font set` above.
  if (mode !== "revert" && rawPath === "") {
    return usageError(
      rt,
      "bg set needs an image path",
      "marchyo bg set ~/pictures/wall.png   (or: marchyo bg set --revert)",
    );
  }
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

// Wallpaper-derived theming (`marchyo theme generate <image>`). matugen turns
// the image into a base16 palette; we materialize a runtime theme dir from it
// (mirroring the scheme assets modules/home/theme-runtime.nix builds) and apply
// it live via activateThemeDir. Runtime-only, like `bg` — a rebuild resets to
// the declarative theme. The override value is a JSON string carrying the
// image path and the requested polarity so `runtime restore` can replay it.

type GenerateValue = { image: string; variant: Variant | "auto" };

function readCurrentColors(): ColorsJsonSchema {
  const path = join(currentThemePointerPath(), "colors.json");
  if (!existsSync(path)) {
    throw new Error(
      "no active theme colors.json (enable marchyo.desktop and rebuild)",
    );
  }
  return ColorsJsonSchema.parse(JSON.parse(readFileSync(path, "utf8")));
}

export const generateThemeChangeBase: ChangeSpec = {
  key: "theme.generate",
  runtimeApply: async (ctx) => {
    const raw = typeof ctx.value === "string" ? ctx.value : null;
    if (raw === null) throw new Error("theme.generate needs a value");
    const spec = JSON.parse(raw) as GenerateValue;

    const { code, stdout } = await captureArgv(matugenArgv(spec.image));
    if (code !== 0 || stdout.trim() === "") {
      throw new Error(
        `matugen failed for ${spec.image} (is matugen installed and the image readable?)`,
      );
    }
    const variant = spec.variant === "auto" ? detectVariant(stdout) : spec.variant;
    const base16 = parseMatugenBase16(stdout, variant);

    const dir = generatedThemeDirPath();
    await mkdir(dir, { recursive: true });
    const colors = recolorShellColors(
      readCurrentColors(),
      base16,
      variant,
      "generated",
    );
    await writeFile(join(dir, "colors.json"), `${JSON.stringify(colors)}\n`);
    await writeFile(join(dir, "variant"), `${variant}\n`);
    await writeFile(join(dir, "hyprland.conf"), hyprlandConfFromBase16(base16));
    await writeFile(join(dir, "ghostty.conf"), ghosttyConfFromBase16(base16));
    await writeFile(join(dir, "fzf.opts"), fzfOptsFromBase16(base16));
    // The source image becomes the theme dir's wallpaper (activateThemeDir
    // reads `wallpaper.png`); relinkConfig gives an atomic symlink swap.
    await relinkConfig(spec.image, join(dir, "wallpaper.png"));

    // Known limitation: unlike a manifest `theme set`, generate does NOT emit
    // mako.conf / waybar.css / gtk.css, so those surfaces keep the previously
    // active theme. Faithfully recolouring them would need the current theme's
    // *full* token→hex (incl. the syn-* tokens waybar/gtk use), but colors.json
    // is deliberately the shell subset (no syn-*), so the data is not available
    // at runtime. The build-time path (mkSchemeThemeDir in theme-runtime.nix)
    // has the full palette and does recolour them; a wallpaper theme that needs
    // those surfaces should be added to marchyo.theme.themes instead.
    await activateThemeDir(ctx, { name: "generated", variant, dir });
    return raw;
  },
  runtimeRevert: async (ctx) => {
    const manifest = await readThemeManifest();
    const entry = declarativeTheme(manifest) ?? manifest[0] ?? null;
    if (entry) await activateThemeDir(ctx, entry);
  },
};

export type ThemeGenerateOpts = {
  light?: boolean;
  dark?: boolean;
  revert?: boolean;
};

export async function runThemeGenerate(
  rt: Runtime,
  rawPath: string,
  opts: ThemeGenerateOpts,
): Promise<number> {
  if (opts.light && opts.dark) {
    return usageError(
      rt,
      "--light and --dark are mutually exclusive",
      "pass one of them (or neither to let matugen decide)",
    );
  }
  const mode = parseChangeFlags(rt, { revert: opts.revert });
  if (mode === 2) return 2;
  if (mode !== "revert" && rawPath === "") {
    return usageError(
      rt,
      "theme generate needs an image path",
      "marchyo theme generate ~/pictures/wall.png   (or: marchyo theme generate --revert)",
    );
  }
  const image = isAbsolute(rawPath) ? rawPath : resolve(rawPath);
  if (mode !== "revert" && !existsSync(image)) {
    err(rt, `no such image: ${image}`);
    return 1;
  }
  const variant: Variant | "auto" = opts.light
    ? "light"
    : opts.dark
      ? "dark"
      : "auto";
  return applyChange(rt, generateThemeChangeBase, {
    mode,
    value: JSON.stringify({ image, variant }),
  });
}
