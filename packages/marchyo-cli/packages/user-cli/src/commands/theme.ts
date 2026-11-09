import { existsSync, readFileSync, readdirSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, extname, isAbsolute, join, resolve } from "node:path";
import {
  type ChangeContext,
  type ChangeSpec,
  type Runtime,
  type State,
  type ThemeManifestEntry,
  type OverrideValue,
  COLOR_SCHEME_KEY,
  TEMPLATE_SURFACE_FILES,
  THEME_ALIASES,
  applyChange,
  awwwImgArgv,
  captureArgv,
  clearOverride,
  colorSchemeGvariant,
  currentThemePointerPath,
  data,
  dconfWriteArgv,
  declarativePointerPath,
  err,
  GENERATED_BAT_THEME,
  ThemePalette,
  appSurfaceTexts,
  batCacheBuildArgv,
  batConfigDirArgv,
  batConfigWithTheme,
  consoleTable,
  fillTemplate,
  fzfOptsFor,
  ghosttyConfFromBase16,
  hyprctlEvalArgv,
  hyprlandAvailable,
  hyprlandConfFor,
  hyprlockColorsFor,
  loadRuntimeState,
  runtimeStatePath,
  gduText,
  k9sSkinText,
  lazygitText,
  spotifyPlayerThemeText,
  matugenArgv,
  ColorsJson as ColorsJsonSchema,
  detectVariant,
  generatedThemeDirPath,
  parseMatugenBase16,
  parseMatugenMaterial,
  recolorShellColors,
  resolvedPalette,
  tmThemeFromBase16,
  tokenResolver,
  tty16FromBase16,
  nextTheme,
  notifySendArgv,
  parseChangeFlags,
  pointCurrentTheme,
  readState,
  setvtrgbArgv,
  readThemeManifest,
  readThemeManifestFile,
  themeAtPointer,
  usageError,
  warn,
  tr,
} from "@marchyo/core";
import type { Variant } from "@marchyo/core";
import { writeGreeterTheme } from "@marchyo/core";
import { mkdir, rename, rm, symlink, writeFile } from "node:fs/promises";
import { activateAppSurfaces } from "./theme-surfaces.ts";

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
async function updateDesktopPreference(
  ctx: ChangeContext,
  entry: Pick<ThemeManifestEntry, "name" | "variant">,
): Promise<void> {
  try {
    const code = await ctx.exec(
      dconfWriteArgv(COLOR_SCHEME_KEY, colorSchemeGvariant(entry.variant)),
    );
    if (code !== 0) throw new Error(`dconf exited ${code}`);
  } catch (cause) {
    throw new Error(
      `Cannot set the desktop preference for '${entry.name}'; check dconf and the user D-Bus session`,
      { cause },
    );
  }
}

export async function activateThemeDir(
  ctx: ChangeContext,
  entry: ThemeManifestEntry,
): Promise<void> {
  if (existsSync(join(entry.dir, "gtk.css"))) await updateDesktopPreference(ctx, entry);
  await activateThemeSurfaces(ctx, entry);
}

async function activateThemeSurfaces(
  ctx: ChangeContext,
  entry: ThemeManifestEntry,
): Promise<void> {
  const gtk = join(entry.dir, "gtk.css");
  await pointCurrentTheme(entry.dir);
  // The greeter follows the session theme (best-effort, skips silently).
  await writeGreeterTheme(entry.dir);

  const wallpaper = join(entry.dir, "wallpaper.png");
  if (existsSync(wallpaper)) await safeExec(ctx, awwwImgArgv(wallpaper));

  const hypr = join(entry.dir, "hyprland.conf");
  if (existsSync(hypr) && hyprlandAvailable()) {
    const table = hyprlandConfigTable(readFileSync(hypr, "utf8"));
    if (Object.keys(table).length > 0) {
      await safeExec(ctx, hyprctlEvalArgv(hyprlandConfigLua(table)));
    }
  }

  if (existsSync(gtk)) {
    await relinkConfig(gtk, join(configHome(), "gtk-3.0", "gtk.css"));
    await relinkConfig(gtk, join(configHome(), "gtk-4.0", "gtk.css"));
  }

  // bat: relink the per-theme config (a `--theme=<name>` line swap, see
  // theme-runtime.nix). No reload signal: bat is a fresh process per run, so
  // the next invocation reads the swapped config. The theme's tmTheme is
  // already in bat's cache (the Jylhis pair ships it, scheme themes are
  // registered via programs.bat.themes, and `theme generate` builds the cache
  // after writing its own), so this is a pure name swap.
  const bat = join(entry.dir, "bat.conf");
  if (existsSync(bat)) {
    await relinkConfig(bat, join(configHome(), "bat", "config"));
  }

  // k9s: its declarative skin links through current-theme, which already
  // follows the switch, but k9s only restyles a running session on a change
  // event in its skins dir. Relinking the skin straight at this theme dir's
  // copy (atomic rename into skins/) fires that event. lazygit,
  // spotify-player and gdu read their current-theme files at start, so they
  // need no step here.
  const k9sSkin = join(entry.dir, "k9s-skin.yaml");
  if (existsSync(k9sSkin)) {
    await relinkConfig(
      k9sSkin,
      join(configHome(), "k9s", "skins", "jylhis.yaml"),
    );
  }

  // console/TTY: best-effort only. setvtrgb repaints the live VT palette, but a
  // Wayland-session process has no controlling console, so this usually no-ops
  // and the TTY instead tracks the declarative console.colors at the next boot
  // (modules/nixos/console.nix). safeExec swallows the missing-binary / not-a-
  // console failure, matching the emit-and-accept-next-boot contract.
  const consoleTable = join(entry.dir, "console.txt");
  if (existsSync(consoleTable)) await safeExec(ctx, setvtrgbArgv(consoleTable));

  // tmux, fcitx5 and the terminal/editor surfaces (see theme-surfaces.ts).
  await activateAppSurfaces((argv) => safeExec(ctx, argv), configHome(), entry.dir);

  await safeExec(ctx, notifySendArgv("Theme", `Switched to ${entry.name}`));
}

async function declarativeTheme(): Promise<ThemeManifestEntry | null> {
  const manifest = await readThemeManifestFile();
  return (
    manifest.defaultTheme ??
    themeAtPointer(manifest.themes, declarativePointerPath()) ??
    manifest.themes[0] ??
    null
  );
}

export async function restoreEffectiveTheme(
  ctx: ChangeContext,
  overrides: Record<string, OverrideValue>,
): Promise<boolean> {
  const selection = overrides["theme.selection"];
  const generated = overrides["theme.generate"];
  if (selection !== undefined && generated !== undefined) {
    throw new Error("Conflicting theme.selection and theme.generate overrides");
  }
  if (selection !== undefined) {
    await themeChangeBase.runtimeApply({ ...ctx, value: selection });
  } else if (generated !== undefined) {
    await generateThemeChangeBase.runtimeApply({ ...ctx, value: generated });
  } else {
    const entry = await declarativeTheme();
    if (!entry) return false;
    await activateThemeDir(ctx, entry);
  }
  return true;
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
    // A catalog theme replaces a generated one; only the live one is replayed.
    await clearOverride("theme.generate");
    return name;
  },
  runtimeRevert: async (ctx) => {
    const entry = await declarativeTheme();
    if (entry) await activateThemeDir(ctx, entry);
  },
};

function themeSpecFor(entry: ThemeManifestEntry): ChangeSpec {
  return {
    ...themeChangeBase,
    stateWrite: (prev: State): State => {
      const { scheme: _scheme, ...theme } = prev.theme ?? {};
      return {
        ...prev,
        theme: entry.name.startsWith("jylhis-")
          ? { ...theme, variant: entry.variant }
          : { ...theme, variant: entry.variant, scheme: entry.name },
      };
    },
    stateDelete: (prev: State): State => {
      const { variant: _variant, scheme: _scheme, ...theme } = prev.theme ?? {};
      const next = { ...prev };
      if (Object.keys(theme).length > 0) next.theme = theme;
      else delete next.theme;
      return next;
    },
  };
}

// Absolute paths of the theme dir's palette card and default wallpaper, for
// the entries that ship them.
function themeImages(dir: string): { preview?: string; wallpaper?: string } {
  const images: { preview?: string; wallpaper?: string } = {};
  const preview = join(dir, "preview.png");
  const wallpaper = join(dir, "wallpaper.png");
  if (existsSync(preview)) images.preview = preview;
  if (existsSync(wallpaper)) images.wallpaper = wallpaper;
  return images;
}

export async function runThemeList(rt: Runtime): Promise<number> {
  const manifest = await readThemeManifest(undefined, (m) => warn(rt, m));
  if (manifest.length === 0) {
    err(rt, tr("theme.noThemeManifestFoundIs"));
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
        ...themeImages(t.dir),
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
    warn(rt, tr("theme.rebuildIsDeprecatedUseApply"));
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
      tr("theme.unknownTheme", rawName),
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
    err(rt, tr("theme.noThemesInTheManifest"));
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
      tr("theme.bgSetNeedsAnImage"),
      "marchyo bg set ~/pictures/wall.png   (or: marchyo bg set --revert)",
    );
  }
  const image = isAbsolute(rawPath) ? rawPath : resolve(rawPath);
  if (mode !== "revert" && !existsSync(image)) {
    err(rt, tr("theme.noSuchImage", image));
    return 1;
  }
  const code = await applyChange(rt, bgChangeBase, { mode, value: image });
  if (code !== 0 || mode === "revert") return code;
  return followWallpaper(rt, image);
}

// `marchyo.theme.followWallpaper`: after a successful `bg set` / `bg next`,
// derive the theme from the new image through the `theme generate` path
// (matugen picks the polarity). Both overrides are recorded, so `runtime
// restore` replays the wallpaper and the generated theme. A failed generation
// leaves the wallpaper in place: it warns and the command still succeeds.
async function followWallpaper(rt: Runtime, image: string): Promise<number> {
  const { followWallpaper } = await readThemeManifestFile();
  if (!followWallpaper) return 0;
  try {
    await applyChange(rt, generateThemeChangeBase, {
      mode: "runtime",
      value: JSON.stringify({ image, variant: "auto" }),
    });
  } catch (e) {
    warn(
      rt,
      tr("theme.wallpaperSetButGeneratingTheme", e instanceof Error ? e.message : String(e)),
    );
  }
  return 0;
}

export type Wallpaper = {
  path: string;
  name: string;
  source: "theme" | "package" | "user";
  current: boolean;
};

const IMAGE_FILE = /\.(png|jpe?g|webp)$/i;

function realOrNull(p: string): string | null {
  try {
    return realpathSync(p);
  } catch {
    return null;
  }
}

function imagesIn(dir: string): string[] {
  try {
    return readdirSync(dir)
      .filter((f) => IMAGE_FILE.test(f))
      .sort()
      .map((f) => join(dir, f));
  } catch {
    return [];
  }
}

function wallpaperName(path: string): string {
  const real = realOrNull(path) ?? path;
  return basename(real, extname(real));
}

// The wallpaper in effect: the runtime `bg.image` override, else the active
// theme's own wallpaper.
async function currentWallpaper(themeDir: string): Promise<string | null> {
  const state = await loadRuntimeState(runtimeStatePath());
  const override = state.overrides["bg.image"];
  if (typeof override === "string" && existsSync(override)) return override;
  const own = join(themeDir, "wallpaper.png");
  return existsSync(own) ? own : null;
}

function themePolarity(themeDir: string): "dark" | "light" | null {
  try {
    const v = readFileSync(join(themeDir, "variant"), "utf8").trim();
    return v === "dark" || v === "light" ? v : null;
  } catch {
    return null;
  }
}

// The wallpaper package ships `<name>-light.png` and `<name>-dark.png`; only
// the active theme's polarity is offered. Images without a suffix always pass.
function matchesPolarity(file: string, polarity: "dark" | "light" | null): boolean {
  const m = /-(light|dark)\.[a-z]+$/i.exec(file);
  return polarity === null || m === null || m[1]!.toLowerCase() === polarity;
}

// Every selectable wallpaper, deduplicated by real path in this order: the
// active theme's own (`wallpaper.png` and `wallpapers/`), the images next to
// the theme wallpaper's target (the wallpaper package directory, of the theme's
// polarity), and
// ~/Pictures/Wallpapers.
export async function listWallpapers(): Promise<Wallpaper[]> {
  // The resolved dir, so a recorded path stays valid after the pointer moves.
  const pointer = currentThemePointerPath();
  const themeDir = realOrNull(pointer) ?? pointer;
  const current = await currentWallpaper(themeDir);
  const currentReal = current === null ? null : realOrNull(current);
  const seen = new Set<string>();
  const out: Wallpaper[] = [];
  const add = (path: string, source: Wallpaper["source"]): void => {
    const real = realOrNull(path);
    if (real === null || seen.has(real)) return;
    seen.add(real);
    out.push({ path, name: wallpaperName(path), source, current: real === currentReal });
  };

  const own = join(themeDir, "wallpaper.png");
  if (existsSync(own)) add(own, "theme");
  for (const f of imagesIn(join(themeDir, "wallpapers"))) add(f, "theme");
  const ownReal = realOrNull(own);
  const polarity = themePolarity(themeDir);
  if (ownReal !== null) {
    for (const f of imagesIn(dirname(ownReal))) {
      if (matchesPolarity(f, polarity)) add(f, "package");
    }
  }
  for (const f of imagesIn(join(homedir(), "Pictures", "Wallpapers"))) add(f, "user");
  return out;
}

export async function runBgList(rt: Runtime): Promise<number> {
  const wallpapers = await listWallpapers();
  data(rt, wallpapers, () =>
    wallpapers.map((w) => `${w.current ? "*" : " "} ${w.name} (${w.source}) ${w.path}`).join("\n"),
  );
  return 0;
}

export async function runBgNext(rt: Runtime): Promise<number> {
  const images = await listWallpapers();
  if (images.length === 0) {
    err(rt, tr("theme.noActiveThemeWallpaperTo"));
    return 1;
  }
  const idx = images.findIndex((w) => w.current);
  const next = images[(idx + 1) % images.length]!.path;
  const code = await applyChange(rt, bgChangeBase, {
    mode: "runtime",
    value: next,
  });
  if (code !== 0) return code;
  return followWallpaper(rt, next);
}

// Wallpaper-derived theming (`marchyo theme generate <image>`). matugen turns
// the image into a base16 palette; we materialize a runtime theme dir from it
// with the same file set modules/home/theme-runtime.nix builds for a catalog
// scheme, and apply it live via activateThemeDir. Token colours resolve
// through the build-variant dir's palette.json (slot per tokenSlots, else the
// build hex), except border, border-strong and accent-subtle, which take
// matugen's Material outline_variant, outline and primary_container when the
// output carries them; gtk and the terminal/editor surfaces
// (TEMPLATE_SURFACE_FILES) are filled from that dir's templates/, and bat
// gets a generated tmTheme registered in its cache. Runtime-only, like `bg`:
// a rebuild resets to the declarative theme. The override value is a JSON
// string carrying the image path and the requested polarity so `runtime
// restore` can replay it.

type GenerateValue = { image: string; variant: Variant | "auto" };

// The build-variant theme dir, the only one carrying templates/. The HM
// profile's declarative pointer targets it; manifest dirs are the fallback,
// and a dir with just palette.json (every templated surface disabled) is
// accepted last.
function buildThemeDir(manifest: ThemeManifestEntry[]): string {
  const candidates = [declarativePointerPath(), ...manifest.map((t) => t.dir)];
  const hasPalette = (d: string): boolean =>
    existsSync(join(d, "palette.json")) && existsSync(join(d, "colors.json"));
  const dir =
    candidates.find((d) => hasPalette(d) && existsSync(join(d, "templates"))) ??
    candidates.find(hasPalette);
  if (dir === undefined) {
    throw new Error(
      "no build theme palette.json (enable marchyo.desktop and rebuild)",
    );
  }
  return dir;
}

// Temp file + rename, so a surface reading the file mid-write (a new fzf)
// never sees a partial one.
async function writeAtomic(path: string, text: string): Promise<void> {
  const tmp = `${path}.tmp-${process.pid}`;
  await writeFile(tmp, text);
  await rename(tmp, path);
}

// bat's config dir, or null when bat is not installed.
async function batConfigDir(): Promise<string | null> {
  const { code, stdout } = await captureArgv(batConfigDirArgv());
  const dir = stdout.trim();
  return code === 0 && dir !== "" ? dir : null;
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

    const baseDir = buildThemeDir(await readThemeManifest());
    const readBase = (f: string): string => readFileSync(join(baseDir, f), "utf8");
    const palette = ThemePalette.parse(JSON.parse(readBase("palette.json")));
    const resolve = tokenResolver(
      palette,
      base16,
      parseMatugenMaterial(stdout, variant),
    );

    const dir = generatedThemeDirPath();
    if (existsSync(join(baseDir, "templates", "gtk.css"))) {
      await updateDesktopPreference(ctx, { name: "generated", variant });
    }
    await mkdir(dir, { recursive: true });
    const put = (f: string, text: string): Promise<void> =>
      writeAtomic(join(dir, f), text);

    const colors = recolorShellColors(
      ColorsJsonSchema.parse(JSON.parse(readBase("colors.json"))),
      palette,
      resolve,
      variant,
      "generated",
    );
    await put("colors.json", `${JSON.stringify(colors)}\n`);
    await put("palette.json", JSON.stringify(resolvedPalette(palette, resolve)));
    await put("variant", `${variant}\n`);
    await put("hyprland.conf", hyprlandConfFor(resolve));
    await put("ghostty.conf", ghosttyConfFromBase16(base16));
    await put("fzf.opts", fzfOptsFor(resolve, base16.base0B!));
    await put("hyprlock-colors.conf", hyprlockColorsFor(resolve));
    await put("console.txt", consoleTable(tty16FromBase16(base16)));
    await put("k9s-skin.yaml", k9sSkinText(base16));
    await put("lazygit.yml", lazygitText(base16));
    await put("spotify-player-theme.toml", spotifyPlayerThemeText(base16));
    await put("gdu.yaml", gduText(base16));
    for (const [file, text] of Object.entries(appSurfaceTexts(base16))) {
      await put(file, text);
    }

    // A surface the build dir has no template for is disabled declaratively;
    // drop any copy an earlier run left so activateThemeDir skips it.
    for (const f of TEMPLATE_SURFACE_FILES) {
      const template = join(baseDir, "templates", f);
      if (existsSync(template)) {
        await put(f, fillTemplate(readFileSync(template, "utf8"), resolve));
      } else {
        await rm(join(dir, f), { force: true });
      }
    }

    // bat selects themes by tmTheme filename stem from its cache: write the
    // generated tmTheme into bat's themes dir, rebuild the cache, and point a
    // copy of the build bat config at it.
    const batDir = existsSync(join(baseDir, "bat.conf"))
      ? await batConfigDir()
      : null;
    if (batDir !== null) {
      await mkdir(join(batDir, "themes"), { recursive: true });
      await writeAtomic(
        join(batDir, "themes", `${GENERATED_BAT_THEME}.tmTheme`),
        tmThemeFromBase16(GENERATED_BAT_THEME, base16),
      );
      await safeExec(ctx, batCacheBuildArgv());
      await put(
        "bat.conf",
        batConfigWithTheme(readBase("bat.conf"), GENERATED_BAT_THEME),
      );
    } else {
      await rm(join(dir, "bat.conf"), { force: true });
    }

    // The source image becomes the theme dir's wallpaper (activateThemeDir
    // reads `wallpaper.png`); relinkConfig gives an atomic symlink swap.
    await relinkConfig(spec.image, join(dir, "wallpaper.png"));

    await activateThemeSurfaces(ctx, { name: "generated", variant, dir });
    await clearOverride("theme.selection");
    return raw;
  },
  runtimeRevert: async (ctx) => {
    const entry = await declarativeTheme();
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
      tr("theme.lightAndDarkAreMutually"),
      "pass one of them (or neither to let matugen decide)",
    );
  }
  const mode = parseChangeFlags(rt, { revert: opts.revert });
  if (mode === 2) return 2;
  if (mode !== "revert" && rawPath === "") {
    return usageError(
      rt,
      tr("theme.themeGenerateNeedsAnImage"),
      "marchyo theme generate ~/pictures/wall.png   (or: marchyo theme generate --revert)",
    );
  }
  const image = isAbsolute(rawPath) ? rawPath : resolve(rawPath);
  if (mode !== "revert" && !existsSync(image)) {
    err(rt, tr("theme.noSuchImage", image));
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
