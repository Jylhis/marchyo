#!/usr/bin/env bun
import { Command } from "commander";
import { runScaffoldModule } from "./commands/scaffold-module.ts";
import { runOptionsSearch } from "./commands/options-search.tsx";

const program = new Command();

program
  .name("marchyoctl")
  .description("Marchyo developer CLI — scaffold modules and inspect options")
  .version("0.1.0");

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
  .action(async (name: string, opts: { repo: string }) => {
    await runScaffoldModule(name, opts.repo);
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
  .action(async (query: string, opts: { repo: string }) => {
    await runOptionsSearch(query, opts.repo);
  });

await program.parseAsync(process.argv);
