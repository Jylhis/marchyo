import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { z } from "zod";
import { shellConfigQmlPath, shellShareDir } from "./shell-ipc.ts";

// Shell plugin kinds and the entry point key each one requires. The set is
// closed: packages/marchyo-shell/plugin.nix declares the same mapping and
// tests/shell/contracts-test.sh asserts the two agree.
export const PLUGIN_KINDS = {
  "bar-widget": "barWidget",
  launcher: "launcher",
  daemon: "daemon",
  bar: "bar",
  panel: "panel",
  menu: "menu",
  overlay: "overlay",
  service: "service",
} as const;

export type PluginKind = keyof typeof PLUGIN_KINDS;

export function isPluginKind(k: string): k is PluginKind {
  return Object.hasOwn(PLUGIN_KINDS, k);
}

// Kinds the dev loader (`marchyo plugin dev`) may mount. The others run at
// startup or replace the bar, so they need a rebuild. Commons/PluginManifest.js
// DEV_KINDS holds the same list.
export const DEV_PLUGIN_KINDS: readonly PluginKind[] = [
  "bar-widget",
  "panel",
  "overlay",
  "menu",
  "launcher",
];

// Id namespaces no plugin may use (packages/marchyo-shell/plugin.nix).
export const RESERVED_ID_NAMESPACES = ["marchyo.", "omarchy."] as const;

export function reservedIdNamespace(id: string): string | null {
  return RESERVED_ID_NAMESPACES.find((ns) => id.startsWith(ns)) ?? null;
}

// Leading characters of the first-party launcher prefixes
// (shell/Commons/LauncherProviders.js PREFIXES). A plugin prefix may not start
// with one; packages/marchyo-shell/plugin.nix applies the same rule.
export const RESERVED_PREFIX_STARTS = ["=", ">", "#", "!"] as const;

// The reserved leading character a launcher prefix starts with, or null.
export function reservedPrefixClash(prefix: string): string | null {
  return RESERVED_PREFIX_STARTS.find((r) => prefix.startsWith(r)) ?? null;
}

// The lock the installed shell bakes at share/marchyo/shell/plugins.lock.json:
// every plugin built into that shell. source is set only for CLI-added
// plugins (marchyo.shell.extraPlugins); flake-declared ones pin in flake.lock.
export const PluginLockSchema = z.object({
  lockVersion: z.literal(1),
  plugins: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      version: z.string(),
      kinds: z.array(z.string()),
      entryPoints: z.record(z.string(), z.string()),
      prefix: z.string().nullable(),
      storePath: z.string(),
      source: z.object({ url: z.string(), rev: z.string() }).nullable(),
      keepLoaded: z.boolean().optional(),
      barWidget: z.record(z.string(), z.unknown()).nullable().optional(),
      // The primary plugin's id for a sibling manifest, else null.
      parent: z.string().nullable().optional(),
    }),
  ),
});

export type PluginLock = z.infer<typeof PluginLockSchema>;

export const PLUGIN_LOCK_FILE = "plugins.lock.json";

// Path of the installed shell's lock, or null when marchyo-shell is not on
// PATH. The file itself may still be absent (a shell built before the lock).
export function pluginLockPath(path: string = process.env.PATH ?? ""): string | null {
  const share = shellShareDir(path);
  return share === null ? null : join(share, PLUGIN_LOCK_FILE);
}

// Parsed lock, or null when there is no installed shell, no lock file, or the
// file does not match the schema.
export function readPluginLock(lockPath: string | null = pluginLockPath()): PluginLock | null {
  if (lockPath === null || !existsSync(lockPath)) return null;
  try {
    const parsed = PluginLockSchema.safeParse(JSON.parse(readFileSync(lockPath, "utf8")));
    return parsed.success ? parsed.data : null;
  } catch {
    return null;
  }
}

// True when the installed shell was built with marchyo.shell.devPlugins.enable
// (its generated Commons/Config.qml bakes `devPlugins: true`).
export function shellDevPluginsEnabled(
  qmlPath: string | null = shellConfigQmlPath(),
): boolean {
  if (qmlPath === null || !existsSync(qmlPath)) return false;
  try {
    return /readonly property bool devPlugins:\s*true\b/.test(readFileSync(qmlPath, "utf8"));
  } catch {
    return false;
  }
}

// The directory `marchyo plugin dev` syncs dev plugins into, and the index the
// shell reads (Commons/PluginIndex.qml).
export function devPluginsDir(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  return join(base, "marchyo", "shell", "dev-plugins");
}
