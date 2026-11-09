import { expect, test } from "bun:test";
import { join } from "node:path";

const CLI = join(import.meta.dir, "..", "src", "cli.tsx");

async function helpOf(path: string[]): Promise<string> {
  const proc = Bun.spawn(["bun", CLI, ...path, "--help"], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1" },
  });
  const out = await new Response(proc.stdout).text();
  await proc.exited;
  return out;
}

const SECTION = /^(Arguments|Options|Commands|Examples):/;

function describe(help: string): string {
  const lines = help.split("\n");
  const start = lines.findIndex((l) => l.startsWith("Usage:"));
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((l) => SECTION.test(l));
  return (end < 0 ? rest : rest.slice(0, end)).join("\n").trim();
}

function subcommands(help: string): string[] {
  const lines = help.split("\n");
  const start = lines.findIndex((l) => l.startsWith("Commands:"));
  if (start < 0) return [];
  const names: string[] = [];
  for (const line of lines.slice(start + 1)) {
    if (line.trim() === "" || SECTION.test(line)) break;
    const m = line.match(/^ {2}([a-z][\w-]*)/);
    if (m && m[1] !== "help") names.push(m[1]!);
  }
  return names;
}

type Finding = { path: string; problem: string };

async function lint(path: string[]): Promise<Finding[]> {
  const help = await helpOf(path);
  const label = `marchyo ${path.join(" ")}`.trim();
  const subs = subcommands(help);
  const findings: Finding[] = [];
  if (path.length > 0 && describe(help) === "") {
    findings.push({ path: label, problem: "no description" });
  }
  if (path.length > 0 && subs.length === 0 && !/^Examples:/m.test(help)) {
    findings.push({ path: label, problem: "no examples" });
  }
  const nested = await Promise.all(subs.map((s) => lint([...path, s])));
  return [...findings, ...nested.flat()];
}

test("every command has a description and every leaf has examples", async () => {
  const findings = await lint([]);
  expect(findings).toEqual([]);
}, 120_000);
