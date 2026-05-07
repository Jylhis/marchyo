#!/usr/bin/env bun
import { Command, Option } from "commander";
import { buildRuntime, type RuntimeFlags } from "@marchyo/core";
import { runStatus } from "./commands/status.tsx";
import { runThemeGet, runThemeSet } from "./commands/theme.ts";
import { runRebuild } from "./commands/rebuild.ts";

const program = new Command();

program
  .name("marchyo")
  .description("Marchyo user CLI — inspect and manage your Marchyo install")
  .version("0.1.0")
  .addOption(
    new Option("-F, --format <fmt>", "output format")
      .choices(["text", "json"])
      .default("text"),
  )
  .option("--no-color", "disable color output (also honors NO_COLOR)")
  .option("--plain", "strip color, glyphs, and animation (a11y mode)")
  .option("--no-animation", "disable spinners and progress animation")
  .option("--no-input", "disable interactive prompts")
  .option("-q, --quiet", "suppress non-error output")
  .option(
    "-v, --verbose",
    "increase verbosity (repeatable)",
    (_, prev: number) => prev + 1,
    0,
  );

program.addHelpText(
  "after",
  `
Examples:
  $ marchyo status
  $ marchyo theme set dark --rebuild
  $ marchyo theme get --format json
  $ marchyo rebuild --dry-run
`,
);

function rt() {
  const o = program.opts<RuntimeFlags>();
  return buildRuntime(o);
}

program
  .command("status")
  .description("Show current Marchyo configuration and system info")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo status
  $ marchyo status --format json | jq .theme.variant
`,
  )
  .action(async () => {
    process.exit(await runStatus(rt()));
  });

const theme = program
  .command("theme")
  .description("Inspect or set the Marchyo theme variant");

theme
  .command("get")
  .description("Print the current theme variant")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo theme get
  $ marchyo theme get --format json
`,
  )
  .action(async () => {
    process.exit(await runThemeGet(rt()));
  });

theme
  .command("set")
  .description("Set the theme variant (writes /etc/marchyo/cli-state.json)")
  .argument("<variant>", "dark | light")
  .option("--rebuild", "Run nixos-rebuild switch after writing state")
  .addHelpText(
    "after",
    `
Examples:
  $ sudo marchyo theme set dark
  $ sudo marchyo theme set light --rebuild
`,
  )
  .action(async (variant: string, opts: { rebuild?: boolean }) => {
    process.exit(
      await runThemeSet(rt(), variant, { rebuild: opts.rebuild ?? false }),
    );
  });

program
  .command("rebuild")
  .description("Run nixos-rebuild switch against the detected flake")
  .option("-n, --dry-run", "Run dry-activate instead of switch")
  .addHelpText(
    "after",
    `
Examples:
  $ sudo marchyo rebuild
  $ sudo marchyo rebuild --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runRebuild(rt(), { dryRun: opts.dryRun ?? false }));
  });

await program.parseAsync(process.argv);
