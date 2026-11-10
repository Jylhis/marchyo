// Unit tests for shell/Commons/Bluetooth.js, the Bluetooth panel's rules.
//
// Run: node tests/shell/bluetooth-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const B = require(path.join(__dirname, "..", "..", "shell", "Commons", "Bluetooth.js"));

function test(name, fn) {
  try {
    fn();
  } catch (error) {
    console.error("not ok - " + name);
    console.error(String(error.message).replace(/^/gm, "    "));
    process.exit(1);
  }
  console.log("ok - " + name);
}

test("rows sort connected, then paired, then new, each by name", () => {
  const rows = [
    { name: "zeta", connected: false, paired: false },
    { name: "Beta", connected: false, paired: true },
    { name: "Mouse", connected: true, paired: true },
    { name: "Alpha", connected: false, paired: true },
    { name: "Buds", connected: true, paired: true },
  ];
  assert.deepEqual(B.sortRows(rows).map((r) => r.name), ["Buds", "Mouse", "Alpha", "Beta", "zeta"]);
  assert.equal(rows[0].name, "zeta");
  assert.deepEqual(B.sortRows(null), []);
});

test("battery text takes a fraction or a percentage and hides unknowns", () => {
  assert.equal(B.batteryText(true, 0.87), "87%");
  assert.equal(B.batteryText(true, 42), "42%");
  assert.equal(B.batteryText(true, 1), "100%");
  assert.equal(B.batteryText(false, 0.5), "");
  assert.equal(B.batteryText(true, -1), "");
  assert.equal(B.batteryText(true, undefined), "");
});

test("a click disconnects, connects or pairs, and ignores a busy device", () => {
  assert.equal(B.actionFor({ connected: true, paired: true }), "disconnect");
  assert.equal(B.actionFor({ connected: false, paired: true }), "connect");
  assert.equal(B.actionFor({ connected: false, paired: false }), "pair");
  assert.equal(B.actionFor({ busy: true, connected: false, paired: true }), "none");
});

console.log("bluetooth tests passed");
