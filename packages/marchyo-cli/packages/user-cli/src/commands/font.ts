import { existsSync, readFileSync } from "node:fs";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import {
  FONT_NAME_KEY,
  type ChangeSpec,
  type Runtime,
  applyChange,
  captureArgv,
  data,
  dconfReadArgv,
  dconfResetArgv,
  dconfWriteArgv,
  err,
  gvariantString,
  parseChangeFlags,
  parseGvariantString,
  patchShellStyle,
  readShellStyle,
  splitFontName,
  usageError,
  warn,
  tr,
} from "@marchyo/core";

// Runtime font switching. The terminal font: Ghostty reads an optional
// override include (wired in modules/home/utilities.nix); writing
// `font-family = <name>` there changes new windows without a rebuild. The UI
// font: the GTK font-name dconf key plus the shell style file (core
// shell-style.ts) the shell watches. Ephemeral like every runtime override:
// `--revert` (or the declarative config, which the includes merely extend) is
// the source of truth.

export const FONT_KINDS = ["mono", "ui", "all"] as const;
export type FontKind = (typeof FONT_KINDS)[number];

const DEFAULT_UI_SIZE = "11";

function fontOverridePath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_CONFIG_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".config");
  return join(base, "marchyo", "font-override.conf");
}

function declarativeFontName(): string | null {
  const path = join(
    process.env.XDG_CONFIG_HOME && process.env.XDG_CONFIG_HOME !== ""
      ? process.env.XDG_CONFIG_HOME
      : join(homedir(), ".config"),
    "marchyo",
    "appearance.json",
  );
  try {
    const raw = JSON.parse(readFileSync(path, "utf8")) as { fontName?: unknown };
    return typeof raw.fontName === "string" && raw.fontName !== "" ? raw.fontName : null;
  } catch {
    return null;
  }
}

type Capture = typeof captureArgv;

async function dconfFontName(capture: Capture = captureArgv): Promise<string | null> {
  const r = await capture(dconfReadArgv(FONT_NAME_KEY));
  return r.code === 0 ? parseGvariantString(r.stdout) : null;
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

// The UI font: dconf font-name (keeping the current size) plus the shell
// style file. Revert restores appearance.json's fontName when the host
// declares one, else clears the dconf key.
export function uiFontSpec(capture: Capture = captureArgv): ChangeSpec {
  return {
    key: "font.ui",
    runtimeApply: async (ctx) => {
      const family = typeof ctx.value === "string" ? ctx.value : null;
      if (family === null || family === "") throw new Error("font.ui needs a font name");
      const current = await dconfFontName(capture);
      const size = (current !== null ? splitFontName(current).size : null) ?? DEFAULT_UI_SIZE;
      try {
        await ctx.exec(dconfWriteArgv(FONT_NAME_KEY, gvariantString(`${family} ${size}`)));
      } catch {
        // best-effort actuation
      }
      await patchShellStyle({ uiFont: family });
      return family;
    },
    runtimeRevert: async (ctx) => {
      await patchShellStyle({ uiFont: null });
      const declared = declarativeFontName();
      try {
        await ctx.exec(
          declared !== null
            ? dconfWriteArgv(FONT_NAME_KEY, gvariantString(declared))
            : dconfResetArgv(FONT_NAME_KEY),
        );
      } catch {
        // best-effort actuation
      }
    },
  };
}

export const uiFontChangeBase = uiFontSpec();

async function fcFamilies(pattern: string): Promise<string[] | null> {
  const r = await captureArgv(["fc-list", pattern, "family"]);
  if (r.code !== 0) return null;
  // fc-list emits comma-separated aliases per line; keep the primary name.
  return [
    ...new Set(
      r.stdout
        .split("\n")
        .map((l) => l.split(",")[0]!.trim())
        .filter((l) => l !== ""),
    ),
  ].sort();
}

export async function fontFamilies(kind: FontKind): Promise<string[] | null> {
  const mono = await fcFamilies(":mono");
  if (kind === "mono") return mono;
  const all = await fcFamilies(":");
  if (all === null) return null;
  if (kind === "all") return all;
  const monoSet = new Set(mono ?? []);
  return all.filter((f) => !monoSet.has(f));
}

async function monoFont(): Promise<string | null> {
  const override = fontOverridePath();
  if (existsSync(override)) {
    const m = readFileSync(override, "utf8").match(/font-family\s*=\s*(.+)/);
    if (m?.[1]) return m[1].trim();
  }
  const r = await captureArgv(["fc-match", "monospace", "--format=%{family}"]);
  return r.code === 0 && r.stdout.trim() !== "" ? r.stdout.trim() : null;
}

async function uiFont(): Promise<string | null> {
  const styled = readShellStyle().uiFont;
  if (styled !== undefined) return styled;
  const dconf = await dconfFontName();
  if (dconf !== null) return splitFontName(dconf).family;
  const r = await captureArgv(["fc-match", "sans-serif", "--format=%{family}"]);
  return r.code === 0 && r.stdout.trim() !== "" ? r.stdout.trim() : null;
}

export async function runFontList(rt: Runtime, kind: FontKind = "mono"): Promise<number> {
  if (!FONT_KINDS.includes(kind)) {
    return usageError(rt, tr("font.invalidKind", kind), "marchyo font list --kind <mono|ui|all>");
  }
  const families = await fontFamilies(kind);
  if (families === null) {
    err(rt, tr("font.fcListFailedFontconfigUnavailable"));
    return 1;
  }
  const current = { mono: await monoFont(), ui: await uiFont() };
  data(rt, { kind, fonts: families, current }, () => families.join("\n"));
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
    err(rt, tr("font.couldNotDetermineTheCurrent"));
    return 1;
  }
  data(rt, { font: { family, source: "declarative" } }, () => family);
  return 0;
}

export type FontSetOpts = { revert?: boolean; kind?: FontKind };

export async function runFontSet(
  rt: Runtime,
  family: string | undefined,
  opts: FontSetOpts,
): Promise<number> {
  const kind = opts.kind ?? "mono";
  if (!FONT_KINDS.includes(kind)) {
    return usageError(rt, tr("font.invalidKind", kind), "marchyo font set <family> --kind <mono|ui|all>");
  }
  const mode = parseChangeFlags(rt, { revert: opts.revert });
  if (mode === 2) return 2;
  if (mode !== "revert" && (family === undefined || family === "")) {
    return usageError(rt, tr("font.fontSetNeedsFontFamily"), "marchyo font set 'BlexMono Nerd Font'");
  }
  if (mode !== "revert") {
    // Warn (not fail) when fontconfig doesn't know the family — the user
    // may be mid-rebuild with the font package incoming.
    const match = await captureArgv(["fc-list", `:family=${family}`, "family"]);
    if (match.code === 0 && match.stdout.trim() === "") {
      warn(rt, tr("font.fontconfigDoesnKnowNewWindows", family!));
    }
  }
  let code = 0;
  if (kind === "mono" || kind === "all") {
    code = await applyChange(rt, fontChangeBase, { mode, value: family });
  }
  if (code === 0 && (kind === "ui" || kind === "all")) {
    code = await applyChange(rt, uiFontChangeBase, { mode, value: family });
  }
  return code;
}
