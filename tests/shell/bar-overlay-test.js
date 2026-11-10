// Unit tests for shell/Commons/BarOverlay.js, the runtime bar layout edits.
//
// Run: node tests/shell/bar-overlay-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Overlay = require(path.join(__dirname, "..", "..", "shell", "Commons", "BarOverlay.js"));

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

const ids = (layout, s) => layout[s].map((e) => e.id);
const base = () => ({
  left: [{ id: "a" }, { id: "b", settings: { k: 1 } }],
  center: [{ id: "clock" }],
  right: [{ id: "x" }, { id: "marchyo.separator" }, { id: "y" }],
});

test("missing sections read as empty", () => {
  const out = Overlay.apply({ left: [{ id: "a" }] }, []);
  assert.deepEqual(out.centerBegin, []);
  assert.deepEqual(out.centerEnd, []);
  assert.deepEqual(ids(out, "left"), ["a"]);
});

test("put moves an entry between sections and keeps its settings", () => {
  const out = Overlay.apply(base(), [{ op: "put", id: "b", section: "right", at: 0 }]);
  assert.deepEqual(ids(out, "left"), ["a"]);
  assert.deepEqual(ids(out, "right"), ["b", "x", "marchyo.separator", "y"]);
  assert.deepEqual(out.right[0].settings, { k: 1 });
});

test("put of a new id appends, and an out-of-range index clamps", () => {
  const out = Overlay.apply(base(), [
    { op: "put", id: "n", section: "centerEnd" },
    { op: "put", id: "m", section: "centerEnd", at: 99 },
  ]);
  assert.deepEqual(ids(out, "centerEnd"), ["n", "m"]);
});

test("a separator is added, never moved", () => {
  const out = Overlay.apply(base(), [{ op: "put", id: "marchyo.separator", section: "left", at: 1 }]);
  assert.deepEqual(ids(out, "left"), ["a", "marchyo.separator", "b"]);
  assert.equal(ids(out, "right").filter((i) => i === "marchyo.separator").length, 1);
});

test("remove drops every entry with the id", () => {
  const out = Overlay.apply(base(), [{ op: "remove", id: "marchyo.separator" }, { op: "remove", id: "a" }]);
  assert.deepEqual(ids(out, "right"), ["x", "y"]);
  assert.deepEqual(ids(out, "left"), ["b"]);
});

test("set replaces a section and pulls listed ids out of the others", () => {
  const out = Overlay.apply(base(), [{ op: "set", section: "center", ids: ["clock", "y", "marchyo.separator", "b"] }]);
  assert.deepEqual(ids(out, "center"), ["clock", "y", "marchyo.separator", "b"]);
  assert.deepEqual(ids(out, "left"), ["a"]);
  assert.deepEqual(ids(out, "right"), ["x", "marchyo.separator"]);
  assert.deepEqual(out.center[3].settings, { k: 1 });
});

test("shift moves within the section and clamps at the ends", () => {
  let out = Overlay.apply(base(), [{ op: "shift", id: "a", by: 1 }]);
  assert.deepEqual(ids(out, "left"), ["b", "a"]);
  out = Overlay.apply(base(), [{ op: "shift", id: "y", by: -9 }]);
  assert.deepEqual(ids(out, "right"), ["y", "x", "marchyo.separator"]);
  out = Overlay.apply(base(), [{ op: "shift", id: "gone", by: 1 }]);
  assert.deepEqual(ids(out, "left"), ["a", "b"]);
});

test("apply never mutates its input", () => {
  const input = base();
  const copy = JSON.stringify(input);
  Overlay.apply(input, [{ op: "put", id: "a", section: "right" }, { op: "remove", id: "x" }]);
  assert.equal(JSON.stringify(input), copy);
});

test("parseOps keeps well-formed ops and drops the rest", () => {
  const text = JSON.stringify({
    ops: [
      { op: "put", id: "a", section: "left", at: 2 },
      { op: "put", id: "a", section: "nowhere" },
      { op: "put", id: "bad id", section: "left" },
      { op: "remove", id: "b" },
      { op: "set", section: "right", ids: ["x", 3] },
      { op: "set", section: "right", ids: ["x"] },
      { op: "shift", id: "c", by: -1.7 },
      { op: "wat" },
      "junk",
    ],
  });
  assert.deepEqual(Overlay.parseOps(text), [
    { op: "put", id: "a", section: "left", at: 2 },
    { op: "remove", id: "b" },
    { op: "set", section: "right", ids: ["x"] },
    { op: "shift", id: "c", by: -1 },
  ]);
});

test("parseOps survives empty, torn and non-object input", () => {
  for (const t of ["", "{", "[]", "null", '{"ops":5}', undefined, null])
    assert.deepEqual(Overlay.parseOps(t), []);
});

console.log("bar overlay tests passed");
