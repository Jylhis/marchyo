import { existsSync, readFileSync } from "node:fs";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import {
  type ChangeSpec,
  type Runtime,
  applyChange,
  captureArgv,
  data,
  err,
  parseChangeFlags,
  usageError,
  warn,
} from "@marchyo/core";

// Runtime terminal-font switching (F3.2). Ghostty reads an optional
// override include (wired in modules/home/utilities.nix); writing
// `font-family = <name>` there changes new windows without a rebuild.
// Ephemeral like every runtime override — activation leaves the file, but
// `--revert` (or the declarative config, which the include merely extends)
// is the source of truth.

function fontOverridePath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_CONFIG_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".config");
  return join(base, "marchyo", "font-override.conf");
}

export const fontChangeBase: ChangeSpec = {
  key: "font.family",
  runtimeApply: async (ctx) => {
    const family = typeof ctx.value === "string" ? ctx.value : null;
    if (family === null) throw new Error("font.family needs a font name");
    const path = fontOverridePath();
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, `font-family = ${family}\n`);
    return family;
  },
  runtimeRevert: async () => {
    await rm(fontOverridePath(), { force: true });
  },
};

export async function runFontList(rt: Runtime): Promise<number> {
  const r = await captureArgv(["fc-list", ":mono", "family"]);
  if (r.code !== 0) {
    err(rt, "fc-list failed (fontconfig unavailable?)");
    return 1;
  }
  // fc-list emits comma-separated aliases per line; keep the primary name.
  const families = [
    ...new Set(
      r.stdout
        .split("\n")
        .map((l) => l.split(",")[0]!.trim())
        .filter((l) => l !== ""),
    ),
  ].sort();
  data(rt, { fonts: families }, () => families.join("\n"));
  return 0;
}

export async function runFontCurrent(rt: Runtime): Promise<number> {
  const override = fontOverridePath();
  if (existsSync(override)) {
    const m = readFileSync(override, "utf8").match(/font-family\s*=\s*(.+)/);
    if (m?.[1]) {
      data(rt, { font: { family: m[1].trim(), source: "runtime" } }, () =>
        m[1]!.trim(),
      );
      return 0;
    }
  }
  const r = await captureArgv(["fc-match", "monospace", "--format=%{family}"]);
  const family = r.code === 0 && r.stdout.trim() !== "" ? r.stdout.trim() : null;
  if (family === null) {
    err(rt, "could not determine the current monospace font");
    return 1;
  }
  data(rt, { font: { family, source: "declarative" } }, () => family);
  return 0;
}

export type FontSetOpts = { revert?: boolean };

export async function runFontSet(
  rt: Runtime,
  family: string | undefined,
  opts: FontSetOpts,
): Promise<number> {
  const mode = parseChangeFlags(rt, { revert: opts.revert });
  if (mode === 2) return 2;
  if (mode !== "revert" && (family === undefined || family === "")) {
    return usageError(rt, "font set needs a font family", "marchyo font set 'JetBrainsMono Nerd Font'");
  }
  if (mode !== "revert") {
    // Warn (not fail) when fontconfig doesn't know the family — the user
    // may be mid-rebuild with the font package incoming.
    const match = await captureArgv(["fc-list", `:family=${family}`, "family"]);
    if (match.code === 0 && match.stdout.trim() === "") {
      warn(rt, `fontconfig doesn't know '${family}' — new windows may fall back`);
    }
  }
  return applyChange(rt, fontChangeBase, { mode, value: family });
}
