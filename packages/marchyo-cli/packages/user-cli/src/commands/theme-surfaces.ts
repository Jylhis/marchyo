import { existsSync, lstatSync, readFileSync, realpathSync } from "node:fs";
import { createHash } from "node:crypto";
import { mkdir, readFile, rename, symlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

// Live application surfaces of a theme dir (see theme-runtime.nix): the files
// tmux, fcitx5 and herdr read through the current-theme pointer need a reload
// signal at most; VS Code, Obsidian and Slack keep their colours in files the
// app owns, so they are written here; btop, kitty, foot, alacritty, helix,
// neovim and Emacs take a relink plus a reload. Every step is best-effort,
// like the other activateThemeDir legs.

export type Exec = (argv: string[]) => Promise<void>;

const stateHome = (): string =>
  process.env.XDG_STATE_HOME || join(homedir(), ".local", "state");

async function writeAtomic(path: string, text: string): Promise<void> {
  await mkdir(join(path, ".."), { recursive: true });
  const tmp = `${path}.tmp-${process.pid}`;
  await writeFile(tmp, text);
  await rename(tmp, path);
}

async function readJson(path: string): Promise<unknown> {
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch {
    return null;
  }
}

// VS Code family: label, settings dir under the config home, extensions dir.
const EDITORS: [string, string][] = [
  [join("Code", "User"), join(".vscode", "extensions")],
  [join("Code - Insiders", "User"), join(".vscode-insiders", "extensions")],
  [join("VSCodium", "User"), join(".vscode-oss", "extensions")],
  [join("Cursor", "User"), join(".cursor", "extensions")],
];

const EXT_ID = "local.marchyo-theme";

// A local colour theme is only discovered through an extension package that is
// registered in extensions.json. The version follows the content, so VS Code
// rebuilds its cached theme when the palette changes.
export async function installVscodeTheme(
  extBase: string,
  settingsPath: string,
  themeText: string,
  variant: string,
): Promise<void> {
  const digest = createHash("sha1").update(themeText).digest("hex");
  const version = `1.0.${parseInt(digest.slice(0, 8), 16)}`;
  const dir = join(extBase, "marchyo-theme");
  await mkdir(join(dir, "themes"), { recursive: true });
  await writeFile(join(dir, "themes", "marchyo-color-theme.json"), themeText);
  await writeFile(
    join(dir, "package.json"),
    JSON.stringify({
      name: "marchyo-theme",
      displayName: "Marchyo",
      publisher: "local",
      version,
      engines: { vscode: "^1.70.0" },
      categories: ["Themes"],
      contributes: {
        themes: [
          {
            label: "Marchyo",
            uiTheme: variant === "light" ? "vs" : "vs-dark",
            path: "./themes/marchyo-color-theme.json",
            _watch: true,
          },
        ],
      },
    }),
  );

  const registryPath = join(extBase, "extensions.json");
  const registry = existsSync(registryPath)
    ? await readJson(registryPath)
    : [];
  if (Array.isArray(registry)) {
    const entries = registry.filter(
      (e: { identifier?: { id?: string } }) => e?.identifier?.id !== EXT_ID,
    );
    entries.push({
      identifier: { id: EXT_ID },
      version,
      location: {
        $mid: 1,
        fsPath: dir,
        external: `file://${dir}`,
        path: dir,
        scheme: "file",
      },
      relativeLocation: "marchyo-theme",
    });
    await writeAtomic(registryPath, `${JSON.stringify(entries)}\n`);
  }
  await selectVscodeTheme(settingsPath);
}

// settings.json is JSONC, so it is edited in place rather than round-tripped.
export async function selectVscodeTheme(settingsPath: string): Promise<void> {
  const text = existsSync(settingsPath)
    ? readFileSync(settingsPath, "utf8")
    : "{\n}\n";
  const key = /("workbench\.colorTheme"\s*:\s*")[^"]*(")/;
  const next = key.test(text)
    ? text.replace(key, "$1Marchyo$2")
    : text.replace("{", '{\n  "workbench.colorTheme": "Marchyo",');
  if (next !== text) await writeAtomic(settingsPath, next);
}

async function syncVscode(
  configHome: string,
  dir: string,
  variant: string,
): Promise<void> {
  const themeFile = join(dir, "vscode-theme.json");
  if (!existsSync(themeFile)) return;
  const text = readFileSync(themeFile, "utf8");
  for (const [settingsDir, extDir] of EDITORS) {
    if (!existsSync(join(configHome, settingsDir))) continue;
    await installVscodeTheme(
      join(homedir(), extDir),
      join(configHome, settingsDir, "settings.json"),
      text,
      variant,
    );
  }
}

// Obsidian: a CSS snippet per vault, enabled in the vault's appearance.json.
async function syncObsidian(configHome: string, dir: string): Promise<void> {
  const cssFile = join(dir, "obsidian.css");
  if (!existsSync(cssFile)) return;
  const cfg = (await readJson(join(configHome, "obsidian", "obsidian.json"))) as {
    vaults?: Record<string, { path?: string }>;
  } | null;
  const css = readFileSync(cssFile, "utf8");
  for (const vault of Object.values(cfg?.vaults ?? {})) {
    const root = join(vault.path ?? "", ".obsidian");
    if (!vault.path || !existsSync(root)) continue;
    await writeAtomic(join(root, "snippets", "marchyo.css"), css);
    const appearancePath = join(root, "appearance.json");
    const appearance =
      ((await readJson(appearancePath)) as Record<string, unknown> | null) ?? {};
    const enabled = Array.isArray(appearance.enabledCssSnippets)
      ? (appearance.enabledCssSnippets as string[])
      : [];
    if (!enabled.includes("marchyo")) {
      await writeAtomic(
        appearancePath,
        `${JSON.stringify({ ...appearance, enabledCssSnippets: [...enabled, "marchyo"] }, null, 2)}\n`,
      );
    }
  }
}

// A Slack theme launcher, when one is installed, watches this directory,
// which it creates; a host without the launcher has none and is skipped.
async function syncSlack(dir: string): Promise<void> {
  const slackDir = join(stateHome(), "marchyo", "slack");
  const theme = join(dir, "slack.json");
  if (existsSync(slackDir) && existsSync(theme)) {
    await writeAtomic(join(slackDir, "theme.json"), readFileSync(theme, "utf8"));
  }
}

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
  variant: string,
): Promise<void> {
  const steps: (() => Promise<void>)[] = [
    () => syncVscode(configHome, dir, variant),
    () => syncObsidian(configHome, dir),
    () => syncSlack(dir),
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
