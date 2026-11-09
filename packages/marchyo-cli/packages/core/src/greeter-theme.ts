import { chmod, open, readFile, rename, rm } from "node:fs/promises";
import { userInfo } from "node:os";
import { join } from "node:path";
import { ColorsJson } from "./matugen.ts";

// The session theme markers the greeter follows. modules/nixos/boot.nix
// tmpfiles-creates the dir (root:users, 1775), each user writes their own
// theme-<user>.json into it, and greeter/Commons/Theme.qml reads the one of
// the last user who logged in; tests/shell/contracts-test.sh keeps the three
// spellings in sync. One file per user: with the sticky bit, a shared file
// name would stay owned by whoever wrote it first.
export const GREETER_THEME_DIR = "/var/lib/marchyo/greeter";

// Login names the greeter accepts in a marker file name (greeter/Commons/
// Theme.qml applies the same pattern).
const USER_NAME = /^[a-z_][a-z0-9_-]{0,31}$/;

export function greeterThemeFile(user: string): string | null {
  return USER_NAME.test(user) ? `theme-${user}.json` : null;
}

// MARCHYO_GREETER_THEME_DIR redirects the marker (the test suite points it at
// a scratch path so a test run never touches the host's real marker).
export function greeterThemeDir(env: NodeJS.ProcessEnv = process.env): string {
  const dir = env.MARCHYO_GREETER_THEME_DIR;
  return dir && dir !== "" ? dir : GREETER_THEME_DIR;
}

const HEX = /^#[0-9a-fA-F]{6}$/;

// Copy a theme dir's colors.json to the greeter marker. Only `#rrggbb`
// colours are carried over; the greeter applies its own key filter.
// Best-effort: an absent marker dir (no greeter on this host), a missing or
// invalid colors.json or an unusable user name skip silently; a marker dir
// that refuses the write is reported on stderr. Returns whether the marker
// was written.
export async function writeGreeterTheme(
  themeDir: string,
  markerDir: string = greeterThemeDir(),
  user: string = userInfo().username,
): Promise<boolean> {
  const file = greeterThemeFile(user);
  if (file === null) return false;
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

  const tmp = join(markerDir, `.${file}.tmp-${process.pid}`);
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
    await rename(tmp, join(markerDir, file));
    return true;
  } catch (err) {
    if (created) await rm(tmp, { force: true }).catch(() => {});
    const code = (err as NodeJS.ErrnoException).code;
    if (code !== "ENOENT") {
      process.stderr.write(
        `marchyo: greeter theme not updated (${join(markerDir, file)}): ${(err as Error).message}\n`,
      );
    }
    return false;
  }
}
