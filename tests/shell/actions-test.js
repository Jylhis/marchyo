// Unit tests for shell/Commons/Actions.js: the dispatcher behind the Hyprland
// global shortcuts and the shell/shortcuts.json parser.
//
// Run: node tests/shell/actions-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const A = require(path.join(__dirname, "..", "..", "shell", "Commons", "Actions.js"));
const shortcutsPath = path.join(__dirname, "..", "..", "shell", "shortcuts.json");

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

const calls = [];
const table = {
  ping: () => "ok",
  togglePanel: (id) => {
    calls.push(id);
    return "ok";
  },
  quiet: () => undefined,
  notAFunction: "x",
};

test("lookup finds own functions only", () => {
  assert.equal(A.lookup(table, "ping"), table.ping);
  assert.equal(A.lookup(table, "notAFunction"), null);
  assert.equal(A.lookup(table, "toString"), null);
  assert.equal(A.lookup(table, "missing"), null);
});

test("call reports whether it ran and passes the arguments", () => {
  assert.deepEqual(A.call(table, "ping", []), { ran: true, output: "ok" });
  assert.deepEqual(A.call(table, "ping", undefined), { ran: true, output: "ok" });
  assert.deepEqual(A.call(table, "togglePanel", ["audio"]), { ran: true, output: "ok" });
  assert.deepEqual(calls, ["audio"]);
  assert.deepEqual(A.call(table, "quiet", []), { ran: true, output: "" });
  assert.deepEqual(A.call(table, "missing", []), { ran: false });
});

test("call refuses the wrong argument count", () => {
  assert.deepEqual(A.call(table, "togglePanel", []), { ran: false });
  assert.deepEqual(A.call(table, "ping", ["x"]), { ran: false });
  assert.deepEqual(calls, ["audio"]);
});

test("parseShortcuts keeps well-formed entries and drops the rest", () => {
  const list = A.parseShortcuts(
    JSON.stringify([
      { name: "panel.audio", call: "togglePanel", args: ["audio"], description: "Audio" },
      { name: "bar", call: "toggleBar" },
      { name: "bar", call: "toggleBar" },
      { name: "bad name", call: "x" },
      { name: "nocall" },
      null,
    ]),
  );
  assert.deepEqual(list, [
    { name: "panel.audio", call: "togglePanel", args: ["audio"], description: "Audio" },
    { name: "bar", call: "toggleBar", args: [], description: "bar" },
  ]);
  assert.deepEqual(A.parseShortcuts("not json"), []);
  assert.deepEqual(A.parseShortcuts("{}"), []);
});

test("shell/shortcuts.json parses with no entry dropped", () => {
  const raw = JSON.parse(fs.readFileSync(shortcutsPath, "utf8"));
  const parsed = A.parseShortcuts(JSON.stringify(raw));
  assert.equal(parsed.length, raw.length);
  for (const e of parsed) assert.ok(e.description !== e.name, e.name + " has no description");
});

console.log(passed + " passed");
