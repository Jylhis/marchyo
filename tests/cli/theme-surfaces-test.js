// Keeps theme-runtime.nix's activation reset in step with what the CLI relinks.
//
// `marchyo theme set/next/generate` repoints HM-managed symlinks at theme dirs
// (relinkConfig in user-cli/src/commands/theme.ts). HM's collision check cannot
// back up a foreign symlink, so theme-runtime.nix's resetThemeRuntimeSurfaces
// activation removes exactly those links before checkLinkTargets runs. The two
// lists are hand-maintained on opposite sides of a language boundary with no
// type system spanning them: add a fifth relink target in the CLI, forget the
// Nix list, and the next `home-manager switch` fails with "would be clobbered"
// — the bug 447aec5 fixed. This is the guard.
//
// Direction matters: the CLI's set must be a SUBSET of the Nix list. Nix may
// list more (the marchyo/current-theme pointer is repointed through a different
// path), but every surface the CLI relinks under $XDG_CONFIG_HOME must be reset.
//
// Run: node tests/cli/theme-surfaces-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..", "..");
const nixFile = path.join(root, "modules", "home", "theme-runtime.nix");
const tsFile = path.join(
  root,
  "packages",
  "marchyo-cli",
  "packages",
  "user-cli",
  "src",
  "commands",
  "theme.ts",
);

const nixSource = fs.readFileSync(nixFile, "utf8");
const tsSource = fs.readFileSync(tsFile, "utf8");

let passed = 0;

function test(name, fn) {
  try {
    fn();
  } catch (error) {
    console.error("not ok - " + name);
    console.error(String(error.message).replace(/^/gm, "    "));
    process.exit(1);
  }
  passed++;
  console.log("ok - " + name);
}

// The `runtimeSurfaces = [ "${config.xdg.configHome}/a/b" ... ];` list.
function nixResetSurfaces() {
  const block = nixSource.match(/runtimeSurfaces\s*=\s*\[([\s\S]*?)\]\s*;/);
  if (!block) return null;
  const out = [];
  const re = /"\$\{config\.xdg\.configHome\}\/([^"]+)"/g;
  let m;
  while ((m = re.exec(block[1]))) out.push(m[1]);
  return out;
}

// Every `relinkConfig(_, join(configHome(), "a", "b"))` target.
function cliRelinkSurfaces() {
  const out = [];
  const re = /relinkConfig\([^,]+,\s*join\(\s*configHome\(\)\s*,([^)]*)\)/g;
  let m;
  while ((m = re.exec(tsSource))) {
    const parts = [...m[1].matchAll(/"([^"]+)"/g)].map((p) => p[1]);
    if (parts.length > 0) out.push(parts.join("/"));
  }
  return out;
}

test("theme-runtime.nix still declares a parseable runtimeSurfaces list", () => {
  const surfaces = nixResetSurfaces();
  assert.ok(surfaces !== null, `no runtimeSurfaces = [ ... ]; list in ${nixFile}`);
  // A silent drop to nothing would make the subset check below vacuous.
  assert.ok(
    surfaces.length >= 4,
    `expected at least 4 reset surfaces, found ${surfaces.length}: ${surfaces.join(", ")}`,
  );
});

test("the CLI's relink targets are still parseable", () => {
  const surfaces = cliRelinkSurfaces();
  assert.ok(
    surfaces.length >= 4,
    `expected at least 4 relinkConfig(configHome()) targets, found ${surfaces.length}: ${surfaces.join(", ")}`,
  );
});

test("every surface the CLI relinks is reset before HM's collision check", () => {
  const reset = new Set(nixResetSurfaces());
  const missing = cliRelinkSurfaces().filter((s) => !reset.has(s));
  assert.deepEqual(
    [...new Set(missing)],
    [],
    "these surfaces are relinked by user-cli/src/commands/theme.ts but not reset by\n" +
      "theme-runtime.nix's resetThemeRuntimeSurfaces, so the next activation will fail\n" +
      "with \"would be clobbered\":\n  " +
      [...new Set(missing)].join("\n  "),
  );
});

console.log("# " + passed + " passed");
