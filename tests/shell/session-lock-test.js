// Unit tests for shell/Commons/SessionLock.js — reading an orphaned session
// lock off `hyprctl -j monitors` so a restarted shell can take it back.
//
// Run: node tests/shell/session-lock-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const modulePath = path.join(__dirname, "..", "..", "shell", "Commons", "SessionLock.js");
const SessionLock = require(modulePath);

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

const monitors = (...blockers) =>
  JSON.stringify(blockers.map((b, i) => ({ name: "OUT-" + i, solitaryBlockedBy: b })));

test("LOCK on the only monitor is locked", () => {
  assert.equal(SessionLock.lockState(monitors(["WINDOWED", "LOCK", "CANDIDATE"])), "locked");
});

test("LOCK on any monitor is locked", () => {
  assert.equal(SessionLock.lockState(monitors(["WINDOWED"], ["LOCK"])), "locked");
});

test("a readable monitor without LOCK is unlocked", () => {
  assert.equal(SessionLock.lockState(monitors(["WINDOWED", "CANDIDATE"])), "unlocked");
});

test("a monitor with no blockers at all is unlocked", () => {
  assert.equal(SessionLock.lockState(JSON.stringify([{ name: "HDMI-A-1" }])), "unlocked");
});

test("only WORKSPACE-blocked monitors are unknown", () => {
  assert.equal(SessionLock.lockState(monitors(["WORKSPACE"])), "unknown");
});

test("no monitors is unknown", () => {
  assert.equal(SessionLock.lockState("[]"), "unknown");
});

test("bad or non-array JSON is unknown", () => {
  assert.equal(SessionLock.lockState(""), "unknown");
  assert.equal(SessionLock.lockState("ok"), "unknown");
  assert.equal(SessionLock.lockState('{"name":"x"}'), "unknown");
});

console.log("# " + passed + " passed");
