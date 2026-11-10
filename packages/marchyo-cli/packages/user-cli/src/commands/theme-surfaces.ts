import { existsSync, lstatSync, readFileSync, realpathSync } from "node:fs";
import { mkdir, rename, symlink } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

// Live application surfaces of a theme dir (see theme-runtime.nix): the files
// tmux and fcitx5 read through the current-theme pointer need a reload signal
// at most; btop, kitty, foot, alacritty, helix, neovim and Emacs take a relink
// plus a reload. Every step is best-effort, like the other activateThemeDir
// legs.

export type Exec = (argv: string[]) => Promise<void>;

const dataHome = (): string =>
  process.env.XDG_DATA_HOME || join(homedir(), ".local", "share");

// Point `link` at `target` unless it already resolves there (a link that
// follows the current-theme pointer is current after the pointer moved) or
// holds a file the user owns: only absent paths and symlinks are replaced.
export async function relinkSurface(target: string, link: string): Promise<void> {
  let kind: "absent" | "link" | "other" = "absent";
  try {
    kind = lstatSync(link).isSymbolicLink() ? "link" : "other";
  } catch {
    // absent
  }
  if (kind === "other") return;
  if (kind === "link") {
    try {
      if (realpathSync(link) === realpathSync(target)) return;
    } catch {
      // dangling link: replace it
    }
  }
  await mkdir(join(link, ".."), { recursive: true });
  const tmp = `${link}.tmp-${process.pid}`;
  await symlink(target, tmp);
  await rename(tmp, link);
}

// Terminal and editor surfaces: relink the app's theme path at this theme dir
// and ask a running instance to reload. Every app tolerates being absent.
async function syncTerminalEditors(
  exec: Exec,
  configHome: string,
  dir: string,
): Promise<void> {
  const file = (name: string): string | null =>
    existsSync(join(dir, name)) ? join(dir, name) : null;
  const links: [string, string][] = [
    ["btop.theme", join(configHome, "btop", "themes", "marchyo.theme")],
    ["kitty.conf", join(configHome, "kitty", "marchyo-theme.conf")],
    ["foot-theme.ini", join(configHome, "foot", "marchyo-theme.ini")],
    ["alacritty-theme.toml", join(configHome, "alacritty", "marchyo-theme.toml")],
    ["helix-theme.toml", join(configHome, "helix", "themes", "marchyo.toml")],
    ["nvim-theme.lua", join(dataHome(), "nvim", "site", "colors", "marchyo.lua")],
  ];
  const reloads: string[][] = [];
  if (file("btop.theme") !== null) reloads.push(["pkill", "-USR2", "-x", "btop"]);
  const kitty = file("kitty.conf");
  if (kitty !== null) reloads.push(["kitty", "@", "set-colors", "-a", "-c", kitty]);
  const attempts: (() => Promise<void>)[] = [
    ...links.map(([name, link]) => async () => {
      const target = file(name);
      if (target !== null) await relinkSurface(target, link);
    }),
    ...reloads.map((argv) => () => exec(argv)),
  ];
  for (const attempt of attempts) {
    try {
      await attempt();
    } catch {
      // one failing surface never blocks the rest
    }
  }
}

async function reloadEmacs(exec: Exec, dir: string): Promise<void> {
  const file = join(dir, "emacs-theme.el");
  if (!existsSync(file)) return;
  await exec([
    "emacsclient",
    "--timeout=2",
    "--eval",
    `(load-file ${JSON.stringify(file)})`,
  ]);
}

// tmux reads the theme through the pointer; a running server only needs the
// file sourced again. Only configs that source the pointer are touched.
async function reloadTmux(
  exec: Exec,
  configHome: string,
  dir: string,
): Promise<void> {
  const conf = join(configHome, "tmux", "tmux.conf");
  const file = join(dir, "tmux.conf");
  if (!existsSync(file) || !existsSync(conf)) return;
  if (!readFileSync(conf, "utf8").includes("marchyo/current-theme")) return;
  await exec(["tmux", "source-file", file]);
}

export async function activateAppSurfaces(
  exec: Exec,
  configHome: string,
  dir: string,
): Promise<void> {
  const steps: (() => Promise<void>)[] = [
    () => reloadTmux(exec, configHome, dir),
    () => syncTerminalEditors(exec, configHome, dir),
    () => reloadEmacs(exec, dir),
    () =>
      exec([
        "busctl",
        "--user",
        "--auto-start=no",
        "call",
        "org.fcitx.Fcitx5",
        "/controller",
        "org.fcitx.Fcitx.Controller1",
        "ReloadAddonConfig",
        "s",
        "classicui",
      ]),
  ];
  for (const step of steps) {
    try {
      await step();
    } catch {
      // A missing app or a read-only file never blocks the theme switch.
    }
  }
}
