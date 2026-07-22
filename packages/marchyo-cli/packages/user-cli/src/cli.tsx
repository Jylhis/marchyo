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
import {
  runBgNext,
  runBgSet,
  runThemeGet,
  runThemeList,
  runThemeNext,
  runThemeSet,
} from "./commands/theme.ts";
import { runRebuild } from "./commands/rebuild.ts";
import { runUpdate } from "./commands/update.ts";
import { runUpgrade } from "./commands/upgrade.ts";
import { runRollback } from "./commands/rollback.ts";
import { runGc } from "./commands/gc.ts";
import { runDiff } from "./commands/diff.ts";
import { runDebug } from "./commands/debug.ts";
import { runRuntimeRestore, runRuntimeStatus } from "./commands/runtime.ts";
import { runToggle } from "./commands/toggle.ts";
import { VERSION } from "./version.ts";

const program = new Command();

program
  .name("marchyo")
  .description("Marchyo user CLI — inspect and manage your Marchyo install")
  .version(VERSION)
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
  $ marchyo theme set nord
  $ marchyo theme set dark --apply
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
  .description("Inspect and switch Marchyo themes at runtime");

theme
  .command("list")
  .description("List switchable themes (marchyo.theme.themes)")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo theme list
  $ marchyo theme list --format json
`,
  )
  .action(async () => {
    process.exit(await runThemeList(rt()));
  });

theme
  .command("get")
  .description("Print the active theme")
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
  .description("Switch the theme live (persist with --apply)")
  .argument("<name>", "a theme from `marchyo theme list` (dark|light = Jylhis pair)")
  .option("--apply", "Also persist to the CLI state file and rebuild")
  .option("--revert", "Undo: back to the declarative theme")
  .option("--rebuild", "Deprecated alias for --apply")
  .addHelpText(
    "after",
    `
Default is a live, ephemeral switch (resets on activation). --apply
additionally persists the selection and runs nixos-rebuild.

Examples:
  $ marchyo theme set nord
  $ marchyo theme set dark
  $ marchyo theme set gruvbox-dark-hard --apply
  $ marchyo theme set nord --revert
`,
  )
  .action(
    async (
      name: string,
      opts: { apply?: boolean; revert?: boolean; rebuild?: boolean },
    ) => {
      process.exit(await runThemeSet(rt(), name, opts));
    },
  );

theme
  .command("next")
  .description("Cycle to the next theme in the manifest")
  .option("--apply", "Also persist to the CLI state file and rebuild")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo theme next
`,
  )
  .action(async (opts: { apply?: boolean }) => {
    process.exit(await runThemeNext(rt(), opts));
  });

const bg = program
  .command("bg")
  .description("Set or cycle the wallpaper (runtime-only)");

bg.command("set")
  .description("Set the wallpaper to an image file")
  .argument("[path]", "image file (omit with --revert)")
  .option("--revert", "Back to the active theme's wallpaper")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bg set ~/Pictures/wall.png
  $ marchyo bg set --revert
`,
  )
  .action(async (path: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runBgSet(rt(), path ?? "", opts));
  });

bg.command("next")
  .description("Cycle through the wallpaper package's images")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bg next
`,
  )
  .action(async () => {
    process.exit(await runBgNext(rt()));
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

program
  .command("debug")
  .description("Print a diagnostics bundle (versions, generation, journal errors)")
  .addHelpText(
    "after",
    `
All probes are best-effort; unavailable data is reported as unknown/null.

Examples:
  $ marchyo debug
  $ marchyo debug --json
`,
  )
  .action(async () => {
    process.exit(await runDebug(rt()));
  });

program
  .command("toggle")
  .description("Flip a desktop toggle live (gaps, nightlight, waybar, …)")
  .argument(
    "<name>",
    "gaps | transparency | nightlight | waybar | touchpad | touchscreen | idle | screensaver | notifications | suspend | hybrid-gpu",
  )
  .argument("[state]", "on | off (omit to flip)")
  .option("--apply", "Also persist declaratively and rebuild (hybrid-gpu only)")
  .option("--revert", "Undo: back to the declarative default")
  .option("--status", "Print the current state instead of toggling")
  .addHelpText(
    "after",
    `
Toggles are live and ephemeral (reset on activation); hybrid-gpu is
--apply-only. --status is scriptable (used by the waybar indicator).

Examples:
  $ marchyo toggle nightlight
  $ marchyo toggle notifications off
  $ marchyo toggle waybar --status
  $ marchyo toggle hybrid-gpu on --apply
`,
  )
  .action(
    async (
      name: string,
      state: string | undefined,
      opts: { apply?: boolean; revert?: boolean; status?: boolean },
    ) => {
      process.exit(await runToggle(rt(), name, state, opts));
    },
  );

const runtime = program
  .command("runtime")
  .description("Inspect or re-apply ephemeral runtime overrides");

runtime
  .command("status")
  .description("List active runtime overrides")
  .addHelpText(
    "after",
    `
Overrides are live changes made by mutating marchyo commands without
--apply. They reset on nixos-rebuild activation.

Examples:
  $ marchyo runtime status
  $ marchyo runtime status --format json
`,
  )
  .action(async () => {
    process.exit(await runRuntimeStatus(rt()));
  });

runtime
  .command("restore")
  .description("Re-apply stored runtime overrides (used at session start)")
  .addHelpText(
    "after",
    `
Idempotent and best-effort; unknown or failing overrides are skipped
with a warning. Wired as a Hyprland exec-once so overrides survive
compositor restarts within a system generation.

Examples:
  $ marchyo runtime restore
`,
  )
  .action(async () => {
    process.exit(await runRuntimeRestore(rt()));
  });

await program.parseAsync(process.argv);
