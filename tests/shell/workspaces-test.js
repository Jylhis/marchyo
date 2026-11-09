// Unit tests for shell/Commons/Workspaces.js: per-monitor workspace blocks.
//
// Run: node tests/shell/workspaces-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const W = require(path.join(__dirname, "..", "..", "shell", "Commons", "Workspaces.js"));

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

test("parseBlocks maps plugged-in connectors and skips unplugged ones", () => {
  const text = "0\teDP-1\tBOE 0x095F\n1\tDP-3\tDell U2720Q ABC\n2\t\tLG 27GL850\n";
  assert.deepEqual(W.parseBlocks(text), { "eDP-1": 0, "DP-3": 1 });
});

test("parseBlocks tolerates empty and malformed input", () => {
  assert.deepEqual(W.parseBlocks(""), {});
  assert.deepEqual(W.parseBlocks(null), {});
  assert.deepEqual(W.parseBlocks("x\tDP-1\tfoo\nnot a row"), {});
});

test("blockOf and slotOf split ids into blocks of ten", () => {
  assert.equal(W.blockOf(1), 0);
  assert.equal(W.blockOf(10), 0);
  assert.equal(W.blockOf(11), 1);
  assert.equal(W.slotOf(10), 10);
  assert.equal(W.slotOf(11), 1);
  assert.equal(W.slotOf(23), 3);
});

test("blockFor prefers the state file, then the active workspace", () => {
  assert.equal(W.blockFor({ "DP-1": 2 }, "DP-1", 5), 2);
  assert.equal(W.blockFor({}, "DP-1", 14), 1);
  assert.equal(W.blockFor({}, "DP-1", -1), 0);
});

test("workspaceIds lists the block's first five, its others, then guests", () => {
  const workspaces = [
    { id: 12, monitor: "DP-1" },
    { id: 18, monitor: "DP-1" },
    { id: 3, monitor: "DP-1" },
    { id: 2, monitor: "eDP-1" },
    { id: -98, monitor: "DP-1" },
  ];
  assert.deepEqual(W.workspaceIds(1, workspaces, "DP-1"), [11, 12, 13, 14, 15, 18, 3]);
  assert.deepEqual(W.workspaceIds(0, workspaces, "eDP-1"), [1, 2, 3, 4, 5]);
});

test("label shows slots for own workspaces and ids for guests", () => {
  assert.equal(W.label(13, 1), "3");
  assert.equal(W.label(20, 1), "10");
  assert.equal(W.label(3, 1), "3");
  assert.equal(W.label(23, 1), "23");
});

console.log(`# ${passed} tests passed`);
