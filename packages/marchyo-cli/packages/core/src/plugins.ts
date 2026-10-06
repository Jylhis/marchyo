import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";
import { shellShareDir } from "./shell-ipc.ts";

// Shell plugin kinds and the entry point key each one requires. The set is
// closed: packages/marchyo-shell/plugin.nix declares the same mapping and
// tests/shell/contracts-test.sh asserts the two agree.
export const PLUGIN_KINDS = {
  "bar-widget": "barWidget",
  launcher: "launcher",
  daemon: "daemon",
} as const;

export type PluginKind = keyof typeof PLUGIN_KINDS;

export function isPluginKind(k: string): k is PluginKind {
  return Object.hasOwn(PLUGIN_KINDS, k);
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
