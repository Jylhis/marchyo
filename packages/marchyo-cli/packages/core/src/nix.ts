import { $ } from "bun";

export type NixEvalOptions = {
  json?: boolean;
  apply?: string;
};

export async function nixEval(
  expr: string,
  opts: NixEvalOptions = {},
): Promise<string> {
  const args = ["eval", "--impure", "--expr", expr];
  if (opts.json) args.push("--json");
  if (opts.apply) args.push("--apply", opts.apply);
  const result = await $`nix ${args}`.quiet().text();
  return result.trim();
}

export async function nixEvalJson<T = unknown>(
  expr: string,
  apply?: string,
): Promise<T> {
  const out = await nixEval(expr, { json: true, apply });
  return JSON.parse(out) as T;
}

export async function getCurrentGenerationNumber(): Promise<number | null> {
  try {
    const result =
      await $`readlink /nix/var/nix/profiles/system`.quiet().text();
    const match = result.match(/system-(\d+)-link/);
    return match?.[1] ? Number(match[1]) : null;
  } catch {
    return null;
  }
}

export async function getCurrentGenerationDate(): Promise<Date | null> {
  try {
    const stats = await Bun.file("/nix/var/nix/profiles/system").stat();
    return new Date(stats.mtimeMs);
  } catch {
    return null;
  }
}
