#!/usr/bin/env bun
import { Command, Option } from "commander";
import {
  buildRuntime,
  FormatError,
  type Runtime,
  type RuntimeFlags,
} from "@marchyo/core";
import { runScaffoldModule } from "./commands/scaffold-module.ts";
import { runOptionsSearch } from "./commands/options-search.tsx";

const program = new Command();

program
  .name("marchyoctl")
  .description("Marchyo developer CLI — scaffold modules and inspect options")
  .version("0.1.0")
  .option("-F, --format <fmt>", "output format (text | json)", "text")
  .option("--json", "alias for --format json")
  .addOption(
    new Option("--color <when>", "color usage")
      .choices(["auto", "always", "never"])
      .default("auto"),
  )
  .option("--no-color", "disable color (alias for --color=never)")
  .option("--plain", "strip color, glyphs, and animation (a11y mode)")
  .option("--no-animation", "disable spinners and progress animation")
  .option("--no-input", "disable interactive prompts (also auto-set under CI=1)")
  .option("-q, --quiet", "suppress non-error output")
  .option(
    "-v, --verbose",
    "increase verbosity (repeatable; also bumped by MARCHYO_DEBUG=1)",
    (_, prev: number) => prev + 1,
    0,
  );

program.addHelpText(
  "after",
  `
Examples:
  $ marchyoctl scaffold module foo
  $ marchyoctl options search keyboard
  $ marchyoctl options search keyboard --format json

Color: honors NO_COLOR, CLICOLOR_FORCE, FORCE_COLOR, --color, --no-color.
       --plain is a stronger a11y switch (no color, no glyphs, no animation).
`,
);

function rt(): Runtime {
  const o = program.opts<RuntimeFlags & { json?: boolean }>();
  const flags: RuntimeFlags = {
    ...o,
    format: o.format === "text" && o.json ? "json" : o.format,
  };
  try {
    return buildRuntime(flags);
  } catch (e) {
    if (e instanceof FormatError) {
      process.stderr.write(`✗ ${e.message}\n`);
      process.exit(2);
    }
    throw e;
  }
}

const scaffold = program
  .command("scaffold")
  .description("Scaffold new Marchyo artifacts");

scaffold
  .command("module")
  .description("Create a new modules/nixos/<name>.nix with a stub test")
  .argument("<name>", "module name (e.g. 'foo')")
  .option(
    "--repo <path>",
    "path to the marchyo repo (defaults to cwd)",
    process.cwd(),
  )
  .addHelpText(
    "after",
    `
Examples:
  $ marchyoctl scaffold module my-feature
  $ marchyoctl scaffold module my-feature --repo ~/code/marchyo
`,
  )
  .action(async (name: string, opts: { repo: string }) => {
    process.exit(await runScaffoldModule(rt(), name, opts.repo));
  });

const options = program
  .command("options")
  .description("Inspect marchyo.* options");

options
  .command("search")
  .description("Fuzzy-search marchyo.* options by path or description")
  .argument("<query>")
  .option(
    "--repo <path>",
    "path to the marchyo flake (defaults to cwd)",
    process.cwd(),
  )
  .addHelpText(
    "after",
    `
Examples:
  $ marchyoctl options search keyboard
  $ marchyoctl options search theme --format json
`,
  )
  .action(async (query: string, opts: { repo: string }) => {
    process.exit(await runOptionsSearch(rt(), query, opts.repo));
  });

await program.parseAsync(process.argv);
