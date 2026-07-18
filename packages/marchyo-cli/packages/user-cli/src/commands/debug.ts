import { $ } from "bun";
import {
  detectFlake,
  getCurrentGenerationNumber,
  getCurrentGenerationDate,
  data,
  type Runtime,
  type FlakeLocation,
} from "@marchyo/core";
import { VERSION } from "../version.ts";

type DebugBundle = {
  cliVersion: string;
  nixosVersion: string | null;
  generation: number | null;
  generationDate: string | null;
  flake: { path: string; source: string; rev: string | null } | null;
  journalErrors: string[] | null;
};

// Every probe is best-effort: a missing binary, non-NixOS host, or
// permission error yields null for that field, never a crash.
async function tryText(argv: string[]): Promise<string | null> {
  try {
    const out = await $`${argv}`.quiet().text();
    const trimmed = out.trim();
    return trimmed === "" ? null : trimmed;
  } catch {
    return null;
  }
}

async function flakeInfo(
  flake: FlakeLocation | null,
): Promise<DebugBundle["flake"]> {
  if (!flake) return null;
  const rev = await tryText(["git", "-C", flake.path, "rev-parse", "HEAD"]);
  return { path: flake.path, source: flake.source, rev };
}

export async function runDebug(rt: Runtime): Promise<number> {
  const [nixosVersion, generation, generationDate, flake, journal] =
    await Promise.all([
      tryText(["nixos-version"]),
      getCurrentGenerationNumber(),
      getCurrentGenerationDate(),
      detectFlake().then(flakeInfo),
      tryText(["journalctl", "-p", "err", "-b", "-n", "50", "--no-pager"]),
    ]);

  const bundle: DebugBundle = {
    cliVersion: VERSION,
    nixosVersion,
    generation,
    generationDate: generationDate?.toISOString() ?? null,
    flake,
    journalErrors: journal?.split("\n") ?? null,
  };

  data(rt, bundle, () => renderText(bundle));
  return 0;
}

function renderText(b: DebugBundle): string {
  const lines = [
    "Marchyo debug bundle",
    "",
    `  CLI version:     ${b.cliVersion}`,
    `  NixOS version:   ${b.nixosVersion ?? "unknown"}`,
    `  Generation:      ${b.generation ?? "unknown"}`,
    `  Last activated:  ${b.generationDate ?? "unknown"}`,
    `  Flake:           ${b.flake ? `${b.flake.path} (${b.flake.source})` : "not detected"}`,
    `  Flake rev:       ${b.flake?.rev ?? "unknown"}`,
    "",
    "Journal errors (this boot, last 50):",
  ];
  if (b.journalErrors === null) {
    lines.push("  (journalctl unavailable)");
  } else {
    for (const line of b.journalErrors) lines.push(`  ${line}`);
  }
  return lines.join("\n");
}
