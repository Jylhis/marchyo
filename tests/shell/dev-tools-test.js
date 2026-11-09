// Unit tests for shell/Commons/DevTools.js: the dev sandbox's output override,
// flags and surface geometry.
//
// Run: node tests/shell/dev-tools-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Dev = require(path.join(__dirname, "..", "..", "shell", "Commons", "DevTools.js"));

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

test("pickOutput keeps the fallback without an override", () => {
  assert.equal(Dev.pickOutput("", ["DP-1", "SHOT"], "DP-1"), "DP-1");
  assert.equal(Dev.pickOutput(undefined, ["DP-1"], "DP-1"), "DP-1");
});

test("pickOutput uses the override when that output exists", () => {
  assert.equal(Dev.pickOutput("SHOT", ["DP-1", "SHOT"], "DP-1"), "SHOT");
});

test("pickOutput ignores an override naming a missing output", () => {
  assert.equal(Dev.pickOutput("SHOT", ["DP-1"], "DP-1"), "DP-1");
  assert.equal(Dev.pickOutput("SHOT", [], ""), "");
});

test("flagOn is true only for the string 1", () => {
  assert.equal(Dev.flagOn("1"), true);
  for (const v of ["", "0", "true", undefined, null])
    assert.equal(Dev.flagOn(v), false);
});

const screen = { width: 1920, height: 1080 };

test("windowOrigin: a fully anchored window sits at its margins", () => {
  const a = { left: true, right: true, top: true, bottom: true };
  assert.deepEqual(Dev.windowOrigin(a, { left: 0, right: 0, top: 0, bottom: 0 }, screen, screen), { x: 0, y: 0 });
});

test("windowOrigin: top-right and bottom-center anchors", () => {
  const m = { left: 0, right: 10, top: 40, bottom: 20 };
  const win = { width: 400, height: 100 };
  assert.deepEqual(Dev.windowOrigin({ top: true, right: true }, m, win, screen), { x: 1510, y: 40 });
  assert.deepEqual(Dev.windowOrigin({ bottom: true }, m, win, screen), { x: 760, y: 960 });
});

test("windowOrigin: the reserved area shrinks the output", () => {
  const z = { left: 0, right: 0, top: 0, bottom: 0 };
  const win = { width: 640, height: 300 };
  assert.deepEqual(Dev.windowOrigin({ top: true }, z, win, screen, [0, 28, 0, 0]), { x: 640, y: 28 });
  assert.deepEqual(Dev.windowOrigin({}, z, win, screen, [0, 28, 0, 0]), { x: 640, y: 404 });
  assert.deepEqual(Dev.windowOrigin({ left: true }, z, win, screen, [50, 0, 0, 0]), { x: 50, y: 390 });
});

test("describe offsets the card by the window origin", () => {
  const out = Dev.describe({
    launcher: { output: "SHOT", origin: { x: 0, y: 0 }, offset: { x: 560.4, y: 200 }, width: 800, height: 120.6 },
    osd: { output: "SHOT", origin: { x: 700, y: 900 }, offset: { x: 0, y: 0 }, width: 200, height: 60 }
  });
  assert.deepEqual(out.launcher, { output: "SHOT", x: 560, y: 200, width: 800, height: 121 });
  assert.deepEqual(out.osd, { output: "SHOT", x: 700, y: 900, width: 200, height: 60 });
  assert.deepEqual(Dev.describe({}), {});
});

test("isSettled needs the quiet period and the frames", () => {
  assert.equal(Dev.isSettled(true, 2, 2), true);
  assert.equal(Dev.isSettled(true, 1, 2), false);
  assert.equal(Dev.isSettled(false, 5, 2), false);
});

console.log("# " + passed + " passed");
