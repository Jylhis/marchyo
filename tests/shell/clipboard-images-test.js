// Unit tests for shell/Commons/ClipboardImages.js: pruning the omarchy
// clipboard images its history no longer references.
//
// Run: node tests/shell/clipboard-images-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const CI = require(path.join(__dirname, "..", "..", "shell", "Commons", "ClipboardImages.js"));

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

const DIR = "/state/omarchy/clipboard-images";

test("referencedImages lists the image paths under the image dir once", () => {
  const history = JSON.stringify([
    { type: "text", text: "hi" },
    { type: "image", path: DIR + "/a.png" },
    { type: "image", path: DIR + "/a.png" },
    { type: "image", path: "/elsewhere/b.png" },
    { type: "image" },
    null
  ]);
  assert.deepEqual(CI.referencedImages(history, DIR), [DIR + "/a.png"]);
  assert.deepEqual(CI.referencedImages("[]", DIR), []);
  assert.deepEqual(CI.referencedImages("", DIR), []);
});

test("an unreadable history prunes nothing", () => {
  assert.equal(CI.referencedImages("{oops", DIR), null);
  assert.equal(CI.referencedImages("{}", DIR), null);
});

test("pruneArgv deletes old unreferenced files and keeps the rest", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "clipboard-images-"));
  const old = Date.now() / 1000 - 600;
  for (const name of ["kept.png", "gone.png", "clipboard.Ab12Cd"]) {
    fs.writeFileSync(path.join(dir, name), "x");
    fs.utimesSync(path.join(dir, name), old, old);
  }
  fs.writeFileSync(path.join(dir, "fresh.png"), "x");
  const argv = CI.pruneArgv("find", dir, [path.join(dir, "kept.png")]);
  const r = spawnSync(argv[0], argv.slice(1));
  assert.equal(r.status, 0, String(r.stderr));
  assert.deepEqual(fs.readdirSync(dir).sort(), ["fresh.png", "kept.png"]);
  fs.rmSync(dir, { recursive: true, force: true });
});

console.log("# " + passed + " passed");
