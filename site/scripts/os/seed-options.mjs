#!/usr/bin/env node
// Regenerates src/os/data/marchyo-options.json , the seed catalogue for the
// MarchyoOption entity , from a marchyo checkout, via
// scripts/os/extract-marchyo-options.nix.
//
//   node site/scripts/os/seed-options.mjs [marchyo-checkout] [nixpkgs-path]
//
// Needs `nix-instantiate` on PATH. nixpkgs-path defaults to `<nixpkgs>`.

import { execFileSync } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const [marchyo = join(here, "..", "..", ".."), nixpkgs] = process.argv.slice(2);
// marchyo modules/<dir> -> the app's platform tags. nix-on-droid has no modules yet.
const PLATFORMS = {
  nixos: "nixos",
  home: "home-manager",
  darwin: "nix-darwin",
};

// marchyo.<segment>… -> the app's option categories.
const CATEGORY_BY_SEGMENT = {
  ai: "ai",
  dictation: "ai",
  desktop: "desktop",
  menus: "desktop",
  osd: "desktop",
  webapps: "desktop",
  keybindingsHelp: "desktop",
  screenshot: "desktop",
  screensaver: "desktop",
  wallpaper: "desktop",
  keyboard: "desktop",
  inputMethod: "desktop",
  reminders: "desktop",
  office: "desktop",
  media: "desktop",
  xournalpp: "desktop",
  utilities: "desktop",
  cli: "shell",
  emacs: "editor",
  theme: "theme",
  security: "security",
  users: "security",
  autoTimezone: "network",
  timezone: "network",
  defaultLocale: "network",
  services: "network",
  development: "development",
  tracking: "development",
  snapshots: "development",
  bees: "performance",
  performance: "performance",
  power: "performance",
  graphics: "graphics",
  hardware: "graphics",
  darwin: "desktop",
  defaults: "desktop",
};

function extract(platformDir) {
  const args = [
    "--eval",
    "--strict",
    "--json",
    join(here, "extract-marchyo-options.nix"),
    "--arg",
    "marchyo",
    marchyo,
    "--argstr",
    "platform",
    platformDir,
    "--arg",
    "nixpkgs",
    nixpkgs ?? "<nixpkgs>",
  ];
  return JSON.parse(
    execFileSync("nix-instantiate", args, { encoding: "utf8" }),
  );
}

const byName = new Map();
for (const [dir, tag] of Object.entries(PLATFORMS)) {
  for (const opt of extract(dir)) {
    const row = byName.get(opt.name) ?? {
      id: opt.name,
      name: opt.name,
      description: (opt.description ?? "").trim(),
      option_type: opt.option_type ?? "unknown",
      default_value: opt.default_value ?? "",
      category: CATEGORY_BY_SEGMENT[opt.name.split(".")[1]] ?? "development",
      platforms: [],
    };
    if (!row.platforms.includes(tag)) row.platforms.push(tag);
    byName.set(opt.name, row);
  }
}

const rows = [...byName.values()].sort((a, b) => a.name.localeCompare(b.name));
const outPath = join(
  here,
  "..",
  "..",
  "src",
  "os",
  "data",
  "marchyo-options.json",
);
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(rows, null, 2) + "\n");
console.log(`wrote ${rows.length} options to ${outPath}`);
