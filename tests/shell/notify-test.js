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

// ── addHistory ───────────────────────────────────────────────────────────────

test("addHistory prepends newest-first", () => {
  let h = [];
  h = Notify.addHistory(h, { id: 1, timeMs: 100, unread: true }, 100, 100, 0);
  h = Notify.addHistory(h, { id: 2, timeMs: 200, unread: true }, 100, 200, 0);
  assert.deepEqual(
    h.map((e) => e.id),
    [2, 1],
  );
});

test("addHistory trims to the cap, dropping the oldest", () => {
  let h = [];
  for (let i = 1; i <= 5; i++) h = Notify.addHistory(h, { id: i, timeMs: i, unread: true }, 3, i, 0);
  assert.deepEqual(
    h.map((e) => e.id),
    [5, 4, 3],
  );
});

test("addHistory prunes entries older than the retention window", () => {
  const maxAge = 1000;
  let h = [
    { id: "old", timeMs: 0, unread: false },
    { id: "recent", timeMs: 900, unread: false },
  ];
  // now = 1500: "old" is 1500ms back (> window), "recent" is 600ms back (kept).
  h = Notify.addHistory(h, { id: "new", timeMs: 1500, unread: true }, 100, 1500, maxAge);
  assert.deepEqual(
    h.map((e) => e.id),
    ["new", "recent"],
  );
});

test("addHistory with maxAgeMs <= 0 keeps everything within the cap", () => {
  let h = [{ id: "ancient", timeMs: 0, unread: false }];
  h = Notify.addHistory(h, { id: "new", timeMs: 9e12, unread: true }, 100, 9e12, 0);
  assert.deepEqual(
    h.map((e) => e.id),
    ["new", "ancient"],
  );
});

// ── unreadCount ──────────────────────────────────────────────────────────────

test("unreadCount counts only unread entries", () => {
  assert.equal(
    Notify.unreadCount([{ unread: true }, { unread: false }, { unread: true }]),
    2,
  );
  assert.equal(Notify.unreadCount([]), 0);
  assert.equal(Notify.unreadCount(null), 0);
});

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(Notify).sort(), [
    "addHistory",
    "evictionIndex",
    "partitionExpired",
    "unreadCount",
  ]);
});

console.log("# " + passed + " passed");
