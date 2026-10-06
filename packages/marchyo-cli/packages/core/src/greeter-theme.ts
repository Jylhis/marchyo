import { chmod, open, readFile, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import { ColorsJson } from "./matugen.ts";

// The session theme marker the greeter follows. modules/nixos/boot.nix
// tmpfiles-creates the dir (root:users, 1775) and greeter/Commons/Theme.qml
// reads theme.json from it; tests/shell/contracts-test.sh keeps the three
// spellings in sync.
export const GREETER_THEME_DIR = "/var/lib/marchyo/greeter";
export const GREETER_THEME_FILE = "theme.json";

// MARCHYO_GREETER_THEME_DIR redirects the marker (the test suite points it at
// a scratch path so a test run never touches the host's real marker).
export function greeterThemeDir(env: NodeJS.ProcessEnv = process.env): string {
  const dir = env.MARCHYO_GREETER_THEME_DIR;
  return dir && dir !== "" ? dir : GREETER_THEME_DIR;
}

const HEX = /^#[0-9a-fA-F]{6}$/;

// Copy a theme dir's colors.json to the greeter marker. Only `#rrggbb`
// colours are carried over; the greeter applies its own key filter.
// Best-effort: an absent or unwritable dir, a missing or invalid
// colors.json, or a marker owned by another user (the sticky bit refuses
// the rename) all skip silently. Returns whether the marker was written.
export async function writeGreeterTheme(
  themeDir: string,
  markerDir: string = greeterThemeDir(),
): Promise<boolean> {
  let parsed: ColorsJson;
  try {
    parsed = ColorsJson.parse(
      JSON.parse(await readFile(join(themeDir, "colors.json"), "utf8")),
    );
  } catch {
    return false;
  }
  const colors: Record<string, string> = {};
  for (const [key, value] of Object.entries(parsed.colors)) {
    if (HEX.test(value)) colors[key] = value;
  }
  const body = `${JSON.stringify({
    name: parsed.name,
    variant: parsed.variant,
    colors,
  })}\n`;

  const tmp = join(markerDir, `.${GREETER_THEME_FILE}.tmp-${process.pid}`);
  let created = false;
  try {
    // "wx" (O_CREAT|O_EXCL) never follows a symlink planted at the temp name.
    const fh = await open(tmp, "wx", 0o644);
    created = true;
    try {
      await fh.writeFile(body);
    } finally {
      await fh.close();
    }
    // The greeter user reads it as "other", whatever the session umask is.
    await chmod(tmp, 0o644);
    await rename(tmp, join(markerDir, GREETER_THEME_FILE));
    return true;
  } catch {
    if (created) await rm(tmp, { force: true }).catch(() => {});
    return false;
  }
}
