// Unit tests for shell/Commons/Dropbox.js, the `dropbox status` parser.
//
// Run: node tests/shell/dropbox-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const D = require(path.join(__dirname, "..", "..", "shell", "Commons", "Dropbox.js"));

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

test("status lines map to a state and keep the first line as detail", () => {
  assert.deepEqual(D.parseStatus("Up to date\n"), { state: "idle", detail: "Up to date" });
  assert.equal(D.parseStatus("Syncing 12 files • 3 min").state, "syncing");
  assert.equal(D.parseStatus("Downloading 2 files").state, "syncing");
  assert.equal(D.parseStatus("Connecting...").state, "connecting");
  assert.equal(D.parseStatus("Dropbox isn't running!").state, "stopped");
  assert.equal(D.parseStatus("something new").state, "unknown");
  assert.deepEqual(D.parseStatus(undefined), { state: "unknown", detail: "" });
});

console.log("dropbox tests passed");
