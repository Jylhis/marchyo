#!/usr/bin/env bun
import { Command, Option } from "commander";
import {
  buildRuntime,
  FormatError,
  err,
  hint,
  type Runtime,
  type RuntimeFlags,
} from "@marchyo/core";
import { runStatus } from "./commands/status.tsx";
import { runThemeGet, runThemeSet } from "./commands/theme.ts";
import { runRebuild } from "./commands/rebuild.ts";
import { runUpdate } from "./commands/update.ts";
import { runUpgrade } from "./commands/upgrade.ts";
import { runRollback } from "./commands/rollback.ts";
import { runGc } from "./commands/gc.ts";
import { runDiff } from "./commands/diff.ts";

const program = new Command();

program
  .name("marchyo")
  .description("Marchyo user CLI — inspect and manage your Marchyo install")
  .version("0.1.0")
  // --format accepts the canonical jylhis vocabulary; only text|json are
  // implemented today. Any other value rejects with a usage error naming
  // the supported subset (validated in core/runtime.ts:parseFormat).
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
  $ marchyo status
  $ marchyo theme set dark --rebuild
  $ marchyo theme get --format json
  $ marchyo rebuild --dry-run

Color: honors NO_COLOR, CLICOLOR_FORCE, FORCE_COLOR, --color, --no-color.
       --plain is a stronger a11y switch (no color, no glyphs, no animation).
`,
);

function rt(): Runtime {
  const o = program.opts<RuntimeFlags & { json?: boolean }>();
  // --json is sugar for --format json. If both are set, --format wins
  // (more specific/explicit).
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
  .description("Set the theme variant (writes the CLI state file)")
  .argument("<variant>", "dark | light")
  .option("--rebuild", "Run nixos-rebuild switch after writing state")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo theme set dark
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
  $ marchyo rebuild
  $ marchyo rebuild --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runRebuild(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("update")
  .description("Update flake inputs (nix flake update) in the detected flake")
  .option("-n, --dry-run", "Print the command instead of running it")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo update
  $ marchyo update --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runUpdate(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("upgrade")
  .description("Update flake inputs, then nixos-rebuild switch")
  .option("-n, --dry-run", "Print the commands instead of running them")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo upgrade
  $ marchyo upgrade --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runUpgrade(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("rollback")
  .description("Switch back to the previous system generation")
  .option("-n, --dry-run", "Print the command instead of running it")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo rollback
  $ marchyo rollback --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runRollback(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("gc")
  .description("Collect Nix garbage (old generations and unreferenced paths)")
  .option(
    "--delete-older-than <period>",
    "delete generations older than <days>d",
    "14d",
  )
  .option("-n, --dry-run", "Print the command instead of running it")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo gc
  $ marchyo gc --delete-older-than 30d
  $ marchyo gc --dry-run
`,
  )
  .action(async (opts: { deleteOlderThan: string; dryRun?: boolean }) => {
    process.exit(
      await runGc(rt(), {
        olderThan: opts.deleteOlderThan,
        dryRun: opts.dryRun ?? false,
      }),
    );
  });

program
  .command("diff")
  .description("Show what changed between system generations (via dix)")
  .option("-n, --dry-run", "Print the command instead of running it")
  .addHelpText(
    "after",
    `
Compares /run/current-system against a newer pending generation when one
exists, otherwise the last two system generations.

Examples:
  $ marchyo diff
  $ marchyo diff --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runDiff(rt(), { dryRun: opts.dryRun ?? false }));
  });

await program.parseAsync(process.argv);
