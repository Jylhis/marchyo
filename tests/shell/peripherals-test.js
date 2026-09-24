// Unit tests for shell/Commons/Peripherals.js — the `solaar show` parser.
//
// This path only fires for a Logitech receiver the kernel will not bind, so
// UPower never sees it and a build machine can never exercise it live. The
// parser therefore has to be provable headless, like Format.js/Notify.js.
//
// Run: node tests/shell/peripherals-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const modulePath = path.join(__dirname, "..", "..", "shell", "Commons", "Peripherals.js");
const Peripherals = require(modulePath);

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

// A representative two-device `solaar show` dump (trimmed to the shape the
// parser reads: numbered device headers plus their battery lines).
const sample = [
  "Solaar version 1.1.13",
  "",
  "Bolt Receiver",
  "  Device path  : /dev/hidraw0",
  "  USB id       : 046d:c548",
  "  Serial       : ABCD1234",
  "",
  "  1: MX Master 3S",
  "     Codename     : MX Master 3S",
  "     Kind         : mouse",
  "     Online, powered",
  "     Battery: 90%, discharging.",
  "",
  "  2: MX Keys",
  "     Codename     : MX Keys",
  "     Kind         : keyboard",
  "     Battery level: 55%",
  "",
].join("\n");

test("parseSolaarShow reads name + pct for each battery-reporting device", () => {
  assert.deepEqual(Peripherals.parseSolaarShow(sample), [
    { name: "MX Master 3S", pct: 90 },
    { name: "MX Keys", pct: 55 },
  ]);
});

test("parseSolaarShow skips a device with no battery line", () => {
  const text = [
    "  1: Wired Thing",
    "     Kind         : mouse",
    "     Online, powered",
    "  2: MX Anywhere",
    "     Battery: 40%, discharging.",
  ].join("\n");
  assert.deepEqual(Peripherals.parseSolaarShow(text), [{ name: "MX Anywhere", pct: 40 }]);
});

test("parseSolaarShow returns an empty list for no devices / empty input", () => {
  assert.deepEqual(Peripherals.parseSolaarShow(""), []);
  assert.deepEqual(Peripherals.parseSolaarShow(null), []);
  assert.deepEqual(Peripherals.parseSolaarShow("Solaar version 1.1.13\n"), []);
});

test("parseSolaarShow associates the battery with the nearest preceding device", () => {
  // Only the first battery line under a header counts; a stray later percentage
  // (e.g. inside another field) must not overwrite it or attach to nothing.
  const text = ["  1: Mouse", "     Battery: 30%, discharging.", "     Some field: 99%"].join("\n");
  assert.deepEqual(Peripherals.parseSolaarShow(text), [{ name: "Mouse", pct: 30 }]);
});

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(Peripherals).sort(), ["parseSolaarShow"]);
});

console.log("# " + passed + " passed");
