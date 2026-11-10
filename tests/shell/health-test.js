// Unit tests for shell/Commons/Health.js: the parsers behind the remote
// session, update, disk and health indicators.
//
// Run: node tests/shell/health-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const H = require(path.join(__dirname, "..", "..", "shell", "Commons", "Health.js"));

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

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(H).sort(), [
    "diskLow",
    "formatKb",
    "parseDf",
    "parseDoctor",
    "parseUpdateCheck",
    "summarizeChecks",
  ]);
});

test("parseDf reads the last df -kP row", () => {
  const out = "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/nvme0n1p2 1000000 900000 100000 91% /nix\n";
  assert.deepEqual(H.parseDf(out), { freePercent: 10, availKb: 100000 });
  assert.equal(H.parseDf(""), null);
  assert.equal(H.parseDf("only a header"), null);
  assert.equal(H.parseDf("h\nfs x y z"), null);
  assert.equal(H.parseDf("h\nfs 0 0 0 0% /"), null);
});

test("diskLow compares free percent against the threshold", () => {
  const df = { freePercent: 10, availKb: 1 };
  assert.equal(H.diskLow(df, 10), true);
  assert.equal(H.diskLow(df, 9), false);
  assert.equal(H.diskLow(null, 50), false);
});

test("formatKb renders GiB", () => {
  assert.equal(H.formatKb(1048576 * 3.25), "3.3 GiB");
  assert.equal(H.formatKb(1048576 * 120), "120 GiB");
});

test("parseDoctor separates failures from warnings", () => {
  const text = JSON.stringify({
    ok: false,
    checks: [
      { name: "a", status: "pass", detail: "" },
      { name: "b", status: "fail", detail: "down" },
      { name: "c", status: "warn", detail: "meh" },
      { name: "d", status: "skip", detail: "" },
    ],
  });
  const r = H.parseDoctor(text);
  assert.deepEqual(r.failed.map((c) => c.name), ["b"]);
  assert.deepEqual(r.warned.map((c) => c.name), ["c"]);
  assert.equal(H.summarizeChecks(r.failed), "b: down");
});

test("parseDoctor reports nothing for unusable output", () => {
  for (const text of ["", "oops", "null", "{}"]) {
    assert.deepEqual(H.parseDoctor(text), { failed: [], warned: [] });
  }
});

test("parseUpdateCheck defaults to no update", () => {
  assert.deepEqual(H.parseUpdateCheck('{"available":true,"locked":"abc","running":"def"}'), {
    available: true,
    locked: "abc",
    running: "def",
  });
  assert.deepEqual(H.parseUpdateCheck("garbage"), { available: false, locked: "", running: "" });
  assert.deepEqual(H.parseUpdateCheck('{"available":"yes"}'), { available: false, locked: "", running: "" });
});
