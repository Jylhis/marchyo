// Unit tests for shell/Commons/Notify.js — the notification stack's decisions.
//
// Same reason these live outside the QML as Format.js (see format-test.js):
// `nix flake check` cannot start Quickshell, and both bugs encoded here shipped
// unnoticed precisely because nothing headless could see them.
//
// Run: node tests/shell/notify-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const modulePath = path.join(__dirname, "..", "..", "shell", "Commons", "Notify.js");
const Notify = require(modulePath);

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

// Entries are newest-first, matching NotificationState.entries.
const critical = (e) => e.critical === true;

// ── evictionIndex ────────────────────────────────────────────────────────────

test("evictionIndex evicts the oldest non-critical entry", () => {
  const entries = [
    { id: "newest", critical: false },
    { id: "middle", critical: true },
    { id: "oldest", critical: false },
  ];
  assert.equal(Notify.evictionIndex(entries, critical), 2);
});

test("evictionIndex skips critical toasts to reach a non-critical one", () => {
  const entries = [
    { id: "newest", critical: false },
    { id: "a", critical: true },
    { id: "b", critical: true },
  ];
  assert.equal(Notify.evictionIndex(entries, critical), 0);
});

test("evictionIndex evicts the oldest critical when everything is critical", () => {
  // The old code returned "nothing to evict" here, and critical toasts never
  // expire on their own, so the visible cap stopped holding and the stack grew
  // without bound.
  const entries = [
    { id: "newest", critical: true },
    { id: "middle", critical: true },
    { id: "oldest", critical: true },
  ];
  assert.equal(Notify.evictionIndex(entries, critical), 2);
});

test("evictionIndex reports nothing to evict for an empty stack", () => {
  assert.equal(Notify.evictionIndex([], critical), -1);
  assert.equal(Notify.evictionIndex(null, critical), -1);
});

// ── partitionExpired ─────────────────────────────────────────────────────────

test("partitionExpired splits on the deadline", () => {
  const entries = [
    { id: "fresh", deadline: 2000 },
    { id: "due", deadline: 1000 },
    { id: "overdue", deadline: 500 },
  ];
  const { expired, kept } = Notify.partitionExpired(entries, 1000);
  assert.deepEqual(
    expired.map((e) => e.id),
    ["due", "overdue"],
  );
  assert.deepEqual(
    kept.map((e) => e.id),
    ["fresh"],
  );
});

test("partitionExpired never expires a zero deadline", () => {
  // deadline 0 = sticky, which is how critical toasts are represented
  // (Style.notifTimeoutCritical is 0).
  const entries = [{ id: "critical", deadline: 0 }];
  const { expired, kept } = Notify.partitionExpired(entries, 9e15);
  assert.deepEqual(expired, []);
  assert.deepEqual(
    kept.map((e) => e.id),
    ["critical"],
  );
});

test("partitionExpired is independent of how often it is called", () => {
  // The regression this guards: expiry used to be a per-delegate Timer, and the
  // view rebuilds every delegate on every add or remove, so each arrival reset
  // the countdown and under a steady trickle nothing ever expired. A deadline
  // recorded once at admission does not care how many times it is read.
  const admitted = 1000;
  const entries = [{ id: "a", deadline: admitted + 5000 }];
  for (const now of [1000, 3000, 4999, 5999]) {
    assert.deepEqual(Notify.partitionExpired(entries, now).expired, []);
  }
  assert.deepEqual(
    Notify.partitionExpired(entries, 6000).expired.map((e) => e.id),
    ["a"],
  );
});

test("partitionExpired handles an empty stack", () => {
  assert.deepEqual(Notify.partitionExpired([], 1), { expired: [], kept: [] });
  assert.deepEqual(Notify.partitionExpired(null, 1), { expired: [], kept: [] });
});

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(Notify).sort(), ["evictionIndex", "partitionExpired"]);
});

console.log("# " + passed + " passed");
