// Keeps site/src/pages/search.astro's hand-maintained option table honest.
//
// That table is a plain TypeScript literal with no generator behind it and,
// until this test, nothing checking it: four of its nine `declared:` paths
// named files that do not exist (options/development.nix, options/media.nix,
// options/office.nix, options/default-apps.nix), and it advertised
// marchyo.defaults.browser as defaulting to "firefox" when the real default is
// "google-chrome". Consumers — and agents reading the site — were being handed
// dead paths and a wrong value.
//
// Checked here rather than by Astro because this is a claim about the repo, not
// about the page: every path must exist, and every marchyo.* option named must
// actually be declared somewhere in the tree.
//
// Run: node tests/site/option-paths-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..", "..");
const searchAstro = path.join(root, "site", "src", "pages", "search.astro");
const source = fs.readFileSync(searchAstro, "utf8");

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

// { name: 'marchyo.x.y', ..., declared: 'path/to/file.nix', ... }
function optionRows() {
  const rows = [];
  const re = /\{\s*name:\s*'([^']+)'[^}]*?declared:\s*'([^']+)'/g;
  let m;
  while ((m = re.exec(source))) rows.push({ name: m[1], declared: m[2] });
  return rows;
}

test("the option table is still parseable and non-empty", () => {
  const rows = optionRows();
  assert.ok(rows.length > 0, "found no option rows in search.astro");
  // A silent drop to a handful would make the checks below vacuous.
  assert.ok(rows.length >= 9, `expected at least 9 option rows, found ${rows.length}`);
});

test("every declared: path exists in the repo", () => {
  const missing = optionRows()
    .filter((row) => !fs.existsSync(path.join(root, row.declared)))
    .map((row) => `${row.name} -> ${row.declared}`);
  assert.deepEqual(missing, [], `these declared: paths do not exist:\n  ${missing.join("\n  ")}`);
});

test("every declared: path really declares the option's namespace", () => {
  const wrong = [];
  for (const row of optionRows()) {
    const file = path.join(root, row.declared);
    if (!fs.existsSync(file)) continue; // reported by the test above
    // marchyo.users.<name>.email -> the "users" namespace.
    const namespace = row.name.split(".")[1];
    const text = fs.readFileSync(file, "utf8");
    // Either the flat form (`options.marchyo.users = { ... }`) or nested under
    // a shared `options.marchyo = { users = { ... }; }` block, which is how
    // feature-flags.nix declares desktop/development/media/office.
    const flat = text.includes(`marchyo.${namespace}`);
    const nested =
      text.includes("options.marchyo") &&
      new RegExp(`^\\s*${namespace}\\s*(=|\\.)`, "m").test(text);
    if (!flat && !nested) {
      wrong.push(`${row.name} -> ${row.declared} does not declare the ${namespace} namespace`);
    }
  }
  assert.deepEqual(wrong, [], `misattributed options:\n  ${wrong.join("\n  ")}`);
});

test("marchyo.defaults.browser advertises its real default", () => {
  const declared = fs.readFileSync(
    path.join(root, "modules", "nixos", "options", "defaults.nix"),
    "utf8",
  );
  const real = declared.match(/browser\s*=\s*mkOption\s*\{[\s\S]*?default\s*=\s*"([^"]+)"/);
  assert.ok(real, "could not read the real default of marchyo.defaults.browser");
  const row = source.match(/name:\s*'marchyo\.defaults\.browser'[^}]*?default:\s*'"([^"]+)"'/);
  assert.ok(row, "could not read the advertised default of marchyo.defaults.browser");
  assert.equal(row[1], real[1]);
});

console.log("# " + passed + " passed");
