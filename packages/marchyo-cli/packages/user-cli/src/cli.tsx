#!/usr/bin/env bun
import { Command } from "commander";
import { runStatus } from "./commands/status.tsx";
import { runTheme } from "./commands/theme.ts";
import { runRebuild } from "./commands/rebuild.ts";

const program = new Command();

program
  .name("marchyo")
  .description("Marchyo user CLI — inspect and manage your Marchyo install")
  .version("0.1.0");

program
  .command("status")
  .description("Show current Marchyo configuration and system info")
  .action(async () => {
    await runStatus();
  });

program
  .command("theme")
  .description("Set theme variant")
  .argument("<variant>", "dark | light")
  .option("--rebuild", "Run nixos-rebuild switch after writing state")
  .action(async (variant: string, opts: { rebuild?: boolean }) => {
    await runTheme(variant, { rebuild: opts.rebuild ?? false });
  });

program
  .command("rebuild")
  .description("Run nixos-rebuild switch against the detected flake")
  .option("--dry", "Run dry-activate instead of switch")
  .action(async (opts: { dry?: boolean }) => {
    await runRebuild({ dry: opts.dry ?? false });
  });

await program.parseAsync(process.argv);
