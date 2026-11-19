// Commons/Tokens.qml is the design system's generated quickshell singleton.
// This checks that it is registered, that its four modes agree on their roles,
// that every Colors.qml role the design system still defines exists in each
// mode, and that every Tokens.desktop.* / Tokens.motion.* key the shell reads
// exists.
//
// Run: node tests/shell/tokens-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const SHELL = path.join(__dirname, "..", "..", "shell");
const read = (...p) => fs.readFileSync(path.join(SHELL, ...p), "utf8");

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

const tokens = read("Commons", "Tokens.qml");
const colors = read("Commons", "Colors.qml");
const qmldir = read("Commons", "qmldir");

function block(name) {
  const m = tokens.match(new RegExp("readonly property var " + name + ": \\(\\{([\\s\\S]*?)\\n    \\}\\)"));
  assert.ok(m, "Tokens.qml declares " + name);
  return m[1];
}

function keys(body) {
  return [...body.matchAll(/^\s{8}"?([\w-]+)"?:/gm)].map((m) => m[1]);
}

const modes = { light: "light", dark: "dark", lightContrast: "light-contrast", darkContrast: "dark-contrast" };

// Roles the design system retired; the palette reader keeps them as aliases
// for the shell's Colors.qml, so Tokens.qml does not define them.
const retired = new Set(["brand", "contour", "decorator"]);
const roles = [...colors.matchAll(/Theme\.palette\.(\w+)/g)].map((m) => m[1]).filter((r) => !retired.has(r));

test("Commons/qmldir registers the Tokens singleton", () => {
  assert.match(qmldir, /^singleton Tokens \d+\.\d+ Tokens\.qml$/m);
  assert.match(tokens, /^pragma Singleton$/m);
});

test("Colors.qml reads a real set of roles", () => {
  assert.ok(roles.length > 15);
  assert.equal(new Set(roles).size, roles.length);
});

for (const [prop, mode] of Object.entries(modes)) {
  test("every live Colors.qml role exists in Tokens." + prop + " (" + mode + ")", () => {
    const have = new Set(keys(block(prop)));
    const missing = roles.filter((r) => !have.has(r));
    assert.deepEqual(missing, []);
  });
}

test("the four modes define the same roles", () => {
  const light = keys(block("light")).sort();
  for (const prop of Object.keys(modes)) assert.deepEqual(keys(block(prop)).sort(), light, prop);
});

test("Tokens.modes names the four modes", () => {
  const m = tokens.match(/readonly property var modes: \(\{(.*)\}\)/);
  assert.ok(m, "Tokens.qml declares modes");
  for (const mode of Object.values(modes)) assert.ok(m[1].includes(mode), mode);
});

test("Tokens.desktop.* and Tokens.motion.* keys read by the shell exist", () => {
  const desktop = new Set(keys(block("desktop")));
  const motion = new Set(keys(block("motion")).filter((k) => !["duration", "curve"].includes(k)));
  const files = [];
  (function walk(d) {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      if (e.isDirectory()) walk(path.join(d, e.name));
      else if (e.name.endsWith(".qml") && e.name !== "Tokens.qml") files.push(path.join(d, e.name));
    }
  })(SHELL);
  for (const f of files) {
    const src = fs.readFileSync(f, "utf8");
    for (const m of src.matchAll(/Tokens\.desktop\.(\w+)/g)) assert.ok(desktop.has(m[1]), f + ": desktop." + m[1]);
    for (const m of src.matchAll(/Tokens\.motion\.(\w+)/g)) assert.ok(motion.has(m[1]), f + ": motion." + m[1]);
  }
});

console.log("tokens-test: all ok");
