import { z } from "zod";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { mkdir, rename, symlink } from "node:fs/promises";
import { realpathSync } from "node:fs";

// The N-theme runtime layer's on-disk contract (modules/home/theme-runtime.nix):
//  - a build-generated manifest listing every switchable theme
//  - the HM-managed current-theme pointer symlink the CLI repoints at runtime

export const ThemeManifestEntry = z.object({
  name: z.string(),
  variant: z.enum(["dark", "light"]),
  dir: z.string(),
});
export type ThemeManifestEntry = z.infer<typeof ThemeManifestEntry>;

const Manifest = z.array(ThemeManifestEntry);

// Back-compat aliases: `marchyo theme set dark|light` selects the Jylhis pair.
export const THEME_ALIASES: Record<string, string> = {
  dark: "jylhis-dark",
  light: "jylhis-light",
};

function xdgDataHome(env: NodeJS.ProcessEnv): string {
  const xdg = env.XDG_DATA_HOME;
  return xdg && xdg !== "" ? xdg : join(homedir(), ".local", "share");
}

function xdgConfigHome(env: NodeJS.ProcessEnv): string {
  const xdg = env.XDG_CONFIG_HOME;
  return xdg && xdg !== "" ? xdg : join(homedir(), ".config");
}

function xdgStateHome(env: NodeJS.ProcessEnv): string {
  const xdg = env.XDG_STATE_HOME;
  return xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
}

export function themeManifestPath(
  env: NodeJS.ProcessEnv = process.env,
): string {
  return join(xdgDataHome(env), "marchyo", "themes", "manifest.json");
}

export function currentThemePointerPath(
  env: NodeJS.ProcessEnv = process.env,
): string {
  return join(xdgConfigHome(env), "marchyo", "current-theme");
}

// Home Manager materializes the *declarative* home files tree in its
// profile; the pointer inside it is what activation resets to. Used by
// `theme set --revert` to find the declarative theme without a rebuild.
export function declarativePointerPath(
  env: NodeJS.ProcessEnv = process.env,
): string {
  return join(
    xdgStateHome(env),
    "nix",
    "profiles",
    "home-manager",
    "home-files",
    ".config",
    "marchyo",
    "current-theme",
  );
}

// Missing or invalid manifest degrades to [] (the module isn't enabled, or
// predates the N-theme layer); `warn` gets a diagnostic for the non-missing
// cases.
export async function readThemeManifest(
  path: string = themeManifestPath(),
  warn: (msg: string) => void = () => {},
): Promise<ThemeManifestEntry[]> {
  const file = Bun.file(path);
  if (!(await file.exists())) return [];
  try {
    return Manifest.parse(JSON.parse(await file.text()));
  } catch {
    warn(`ignoring invalid theme manifest at ${path}`);
    return [];
  }
}

function realpathOrNull(p: string): string | null {
  try {
    return realpathSync(p);
  } catch {
    return null;
  }
}

// Which manifest entry a pointer symlink currently targets (null when the
// pointer is missing or targets something outside the manifest).
export function themeAtPointer(
  manifest: ThemeManifestEntry[],
  pointerPath: string = currentThemePointerPath(),
): ThemeManifestEntry | null {
  const resolved = realpathOrNull(pointerPath);
  if (resolved === null) return null;
  return (
    manifest.find((t) => realpathOrNull(t.dir) === resolved) ?? null
  );
}

// Atomic `ln -sfn`: symlink to a temp name, rename over the target.
export async function pointCurrentTheme(
  dir: string,
  pointerPath: string = currentThemePointerPath(),
): Promise<void> {
  await mkdir(dirname(pointerPath), { recursive: true });
  const tmp = `${pointerPath}.tmp-${process.pid}`;
  await symlink(dir, tmp);
  await rename(tmp, pointerPath);
}

export function nextTheme(
  manifest: ThemeManifestEntry[],
  current: ThemeManifestEntry | null,
): ThemeManifestEntry | null {
  if (manifest.length === 0) return null;
  const first = manifest[0]!;
  if (current === null) return first;
  const idx = manifest.findIndex((t) => t.name === current.name);
  if (idx === -1) return first;
  return manifest[(idx + 1) % manifest.length]!;
}
