import { existsSync } from "node:fs";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { type Runtime, data, err, info, ok, tr, usageError } from "@marchyo/core";
import { DEVENV_YAML, ENVRC, LANGUAGE_TEMPLATES } from "../dev-templates.ts";

export const DB_PRESETS: Record<string, { attr: string; needsPkgs: boolean; block: string }> = {
  postgres: {
    attr: "postgres",
    needsPkgs: false,
    block: [
      "  services.postgres = {",
      "    enable = true;",
      '    initialDatabases = [ { name = "app"; } ];',
      "  };",
    ].join("\n"),
  },
  mysql: {
    attr: "mysql",
    needsPkgs: false,
    block: [
      "  services.mysql = {",
      "    enable = true;",
      '    initialDatabases = [ { name = "app"; } ];',
      "  };",
    ].join("\n"),
  },
  mariadb: {
    attr: "mysql",
    needsPkgs: true,
    block: [
      "  services.mysql = {",
      "    enable = true;",
      "    package = pkgs.mariadb;",
      '    initialDatabases = [ { name = "app"; } ];',
      "  };",
    ].join("\n"),
  },
  redis: { attr: "redis", needsPkgs: false, block: "  services.redis.enable = true;" },
  mongodb: { attr: "mongodb", needsPkgs: false, block: "  services.mongodb.enable = true;" },
};

const FILES = ["devenv.nix", "devenv.yaml", ".envrc"] as const;

export function devLanguages(): string[] {
  return Object.keys(LANGUAGE_TEMPLATES).sort();
}

export async function runDevInit(
  rt: Runtime,
  lang: string,
  opts: { force?: boolean },
  cwd: string = process.cwd(),
): Promise<number> {
  const template = LANGUAGE_TEMPLATES[lang];
  if (template === undefined) {
    return usageError(rt, tr("dev.unknownLanguage", lang, devLanguages().join(", ")));
  }
  const existing = FILES.filter((f) => existsSync(join(cwd, f)));
  if (existing.length > 0 && !opts.force) {
    err(rt, tr("dev.wouldOverwrite", existing.join(", ")));
    info(rt, tr("dev.useForce"));
    return 1;
  }
  await writeFile(join(cwd, "devenv.nix"), template);
  await writeFile(join(cwd, "devenv.yaml"), DEVENV_YAML);
  await writeFile(join(cwd, ".envrc"), ENVRC);
  ok(rt, tr("dev.initialised", lang));
  info(rt, tr("dev.nextSteps"));
  data(rt, { language: lang, files: [...FILES] }, () => FILES.join("\n"));
  return 0;
}

export type DbOutcome = { status: "added" | "present" } | { status: "refused"; reason: string };

export function addDbPreset(source: string, engine: string): DbOutcome & { text: string } {
  const preset = DB_PRESETS[engine]!;
  const keep = (reason: string) => ({ status: "refused" as const, reason, text: source });
  if (new RegExp(`\\bservices\\.${preset.attr}\\b`).test(source)) {
    return { status: "present", text: source };
  }
  const lines = source.replace(/\n+$/, "").split("\n");
  const head = lines[0] ?? "";
  if (!/^\{.*\}:\s*$/.test(head) || lines[lines.length - 1] !== "}") {
    return keep("shape");
  }
  if (preset.needsPkgs && !/\bpkgs\b/.test(head)) return keep("pkgs");
  const body = lines.slice(0, -1);
  const last = body[body.length - 1] ?? "";
  if (last.trim() !== "") body.push("");
  return { status: "added", text: [...body, preset.block, "}", ""].join("\n") };
}

export async function runDevDb(
  rt: Runtime,
  engine: string,
  cwd: string = process.cwd(),
): Promise<number> {
  if (DB_PRESETS[engine] === undefined) {
    return usageError(rt, tr("dev.unknownEngine", engine, Object.keys(DB_PRESETS).join(", ")));
  }
  const path = join(cwd, "devenv.nix");
  if (!existsSync(path)) {
    err(rt, tr("dev.noDevenv"));
    info(rt, tr("dev.runInit"));
    return 1;
  }
  const result = addDbPreset(await readFile(path, "utf8"), engine);
  if (result.status === "refused") {
    err(rt, tr(result.reason === "pkgs" ? "dev.needsPkgs" : "dev.unexpectedShape"));
    return 1;
  }
  if (result.status === "added") await writeFile(path, result.text);
  const key = result.status === "added" ? "dev.dbAdded" : "dev.dbPresent";
  ok(rt, tr(key, engine));
  data(rt, { engine, status: result.status }, () => result.status);
  return 0;
}
