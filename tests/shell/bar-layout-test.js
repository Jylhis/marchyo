// Unit tests for shell/Commons/BarLayout.js — the bar's separator decisions.
//
// Same reason these live outside the QML as Format.js (see format-test.js):
// `nix flake check` cannot start Quickshell, and layout bugs like orphaned
// separators between hidden widgets ship unnoticed precisely because nothing
// headless can see them.
//
// Run: node tests/shell/bar-layout-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const modulePath = path.join(__dirname, "..", "..", "shell", "Commons", "BarLayout.js");
const BarLayout = require(modulePath);

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

const SEP = "marchyo.separator";

// Visibility of separator entries under separatorVisibility(ids, shown).
// ids: entry ids; shown: effective visibility of every entry (separators
// themselves pass false — their rendering is what this function decides).
const seps = (ids, shown) => BarLayout.separatorVisibility(ids, shown);

// ── the rules render between two clusters with visible content ──────────────

test("a separator between two visible widgets renders", () => {
  const ids = ["a", SEP, "b"];
  assert.deepEqual(seps(ids, [true, false, true]), [false, true, false]);
});

test("every separator renders when all clusters are populated", () => {
  const ids = ["a", SEP, "b", SEP, "c"];
  assert.deepEqual(seps(ids, [true, false, true, false, true]), [false, true, false, true, false]);
});

// ── empty edge clusters leave no orphaned rules ─────────────────────────────

test("a separator before any visible content stays hidden", () => {
  // Leading cluster empty: screenRecording + reminders idle before the first
  // rule of the right group.
  const ids = ["a", "b", SEP, "c"];
  assert.deepEqual(seps(ids, [false, false, false, true]), [false, false, false, false]);
});

test("a separator after the last visible content stays hidden", () => {
  // Trailing cluster empty: battery + peripherals absent on a desktop.
  const ids = ["a", SEP, "b", "c"];
  assert.deepEqual(seps(ids, [true, false, false, false]), [false, false, false, false]);
});

test("a separator with hidden content only on one side stays hidden", () => {
  const ids = ["a", SEP, "b"];
  assert.deepEqual(seps(ids, [true, false, false]), [false, false, false]);
  assert.deepEqual(seps(ids, [false, false, true]), [false, false, false]);
});

// ── empty middle clusters collapse their rules to one ───────────────────────

test("an empty middle cluster renders exactly one rule, on its left edge", () => {
  // tray visible, media idle (hidden), then the toggles cluster: the bar shows
  // one rule between tray and toggles, not one on each side of the dead media
  // slot.
  const ids = ["a", SEP, "b", SEP, "c"];
  assert.deepEqual(seps(ids, [true, false, false, false, true]), [false, true, false, false, false]);
});

test("adjacent separators collapse to one", () => {
  const ids = ["a", SEP, SEP, "b"];
  assert.deepEqual(seps(ids, [true, false, false, true]), [false, true, false, false]);
});

test("a run of separators collapses to the first", () => {
  const ids = ["a", SEP, SEP, SEP, "b"];
  assert.deepEqual(seps(ids, [true, false, false, false, true]), [false, true, false, false, false]);
});

test("hidden widgets between two rules do not duplicate them", () => {
  // b's cluster is empty; the single rendered rule is the one before it.
  const ids = ["a", SEP, "b", SEP, "c", SEP, "d"];
  assert.deepEqual(seps(ids, [true, false, false, false, true, false, true]), [
    false,
    true,
    false,
    false,
    false,
    true,
    false,
  ]);
});

// ── degenerate sections ─────────────────────────────────────────────────────

test("a section with no separators returns all false", () => {
  assert.deepEqual(seps(["a", "b"], [true, true]), [false, false]);
});

test("a fully hidden section hides every separator", () => {
  const ids = ["a", SEP, "b", SEP, "c"];
  assert.deepEqual(seps(ids, [false, false, false, false, false]), [false, false, false, false, false]);
});

test("an empty section yields an empty result", () => {
  assert.deepEqual(seps([], []), []);
});

// ── defensive input ─────────────────────────────────────────────────────────

test("missing or non-boolean shown entries read as hidden", () => {
  const ids = ["a", SEP, "b"];
  assert.deepEqual(seps(ids, [true, false, undefined]), [false, false, false]);
  assert.deepEqual(seps(ids, new Array(3)), [false, false, false]);
});

test("a shown array shorter than ids does not throw", () => {
  const ids = ["a", SEP, "b"];
  assert.deepEqual(seps(ids, [true]), [false, false, false]);
});

test("null ids or null shown return an empty array", () => {
  assert.deepEqual(BarLayout.separatorVisibility(null, null), []);
});

// ── module surface ──────────────────────────────────────────────────────────

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(BarLayout).sort(), ["SEPARATOR_ID", "separatorVisibility"]);
});

console.log("# " + passed + " passed");
