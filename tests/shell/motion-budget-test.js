// Motion budget for the Quickshell tree: every transition length goes through
// Style.duration(), and none exceeds the longest Jylhis motion token.
//
// Run: node tests/shell/motion-budget-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const SHELL = path.join(__dirname, "..", "..", "shell");
const SKIP_DIRS = new Set(["compat"]);
const SKIP_FILES = new Set(["harness.qml", path.join("Commons", "Style.qml")]);

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

function qmlFiles(dir, rel = "") {
  const out = [];
  for (const entry of fs.readdirSync(path.join(dir, rel), { withFileTypes: true })) {
    const next = path.join(rel, entry.name);
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(entry.name)) out.push(...qmlFiles(dir, next));
    } else if (entry.name.endsWith(".qml") && !SKIP_FILES.has(next)) {
      out.push(next);
    }
  }
  return out;
}

const stripComment = (line) => line.replace(/\/\/.*$/, "");

function motionLong() {
  const style = fs.readFileSync(path.join(SHELL, "Commons", "Style.qml"), "utf8");
  const m = style.match(/property int motionLong:\s*(\d+)/);
  assert.ok(m, "Commons/Style.qml declares motionLong");
  return Number(m[1]);
}

const files = qmlFiles(SHELL);
const lines = files.flatMap((rel) =>
  fs
    .readFileSync(path.join(SHELL, rel), "utf8")
    .split("\n")
    .map((text, i) => ({ where: `shell/${rel}:${i + 1}`, text: stripComment(text) })),
);

test("the scan covers the animated surfaces", () => {
  assert.ok(files.length > 20);
  assert.ok(files.some((f) => f.endsWith("NotificationList.qml")));
});

test("no animation duration is a bare literal", () => {
  const bad = lines
    .filter((l) => /\bduration:\s*\d/.test(l.text))
    .map((l) => `${l.where}: ${l.text.trim()} (wrap it in Style.duration())`);
  assert.deepEqual(bad, []);
});

test("no Style.duration() literal exceeds the longest motion token", () => {
  const budget = motionLong();
  const bad = [];
  for (const l of lines) {
    for (const m of l.text.matchAll(/Style\.duration\(\s*(\d+)\s*\)/g)) {
      if (Number(m[1]) > budget) bad.push(`${l.where}: ${m[1]} ms > ${budget} ms`);
    }
  }
  assert.deepEqual(bad, []);
});

test("nothing outside Style reads animationDuration directly", () => {
  const bad = lines
    .filter((l) => /Style\.animationDuration/.test(l.text))
    .map((l) => `${l.where}: use Style.duration()`);
  assert.deepEqual(bad, []);
});

test("every animation sets a duration", () => {
  const bad = [];
  for (const rel of files) {
    const src = fs.readFileSync(path.join(SHELL, rel), "utf8");
    for (const b of src.matchAll(/\b(?:Number|Color|Property)Animation\s*\{([^{}]*)\}/g)) {
      if (!/duration:/.test(b[1])) bad.push(`shell/${rel}: an animation has no explicit duration`);
    }
  }
  assert.deepEqual(bad, []);
});
