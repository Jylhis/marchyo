// Unit tests for shell/Commons/LauncherRoutes.js: where a launcher mode goes
// while a plugin replaces its role, and the omarchy.menu dmenu payload.
//
// Run: node tests/shell/launcher-routes-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const R = require(path.join(__dirname, "..", "..", "shell", "Commons", "LauncherRoutes.js"));

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

const none = () => "";
const all = (role) =>
  ({
    launcher: "omarchy.menu",
    "launcher.emoji": "omarchy.emojis",
    "launcher.clipboard": "omarchy.clipboard",
  })[role] || "";
const menuOnly = (role) => (role === "launcher" ? "omarchy.menu" : "");

test("native modes stay native without a replacement", () => {
  for (const mode of ["apps", "menu", "emoji", "clipboard", "keys", "theme", "font"])
    assert.equal(R.target(mode, "", none), null);
});

test("menu routes go to the replacing menu, the root as root", () => {
  assert.deepEqual(R.target("menu", "", all), { plugin: "omarchy.menu", payload: { menu: "root" } });
  assert.deepEqual(R.target("menu", "system", all), {
    plugin: "omarchy.menu",
    payload: { menu: "system" },
  });
});

test("apps, font and keys open their menu routes", () => {
  assert.deepEqual(R.target("apps", "", all).payload, { menu: "apps" });
  assert.deepEqual(R.target("font", "", all).payload, { menu: "appearance.font" });
  assert.deepEqual(R.target("keys", "", all).payload, { menu: "keys" });
});

test("theme opens the native theme picker", () => {
  assert.deepEqual(R.target("theme", "", all), { panel: "themes" });
});

test("emoji and clipboard follow their own roles", () => {
  assert.deepEqual(R.target("emoji", "", all), { plugin: "omarchy.emojis", payload: {} });
  assert.deepEqual(R.target("clipboard", "", all), { plugin: "omarchy.clipboard", payload: {} });
  assert.equal(R.target("emoji", "", menuOnly), null);
  assert.equal(R.target("clipboard", "", menuOnly), null);
});

test("request paths are checked like the native dmenu mode", () => {
  assert.ok(R.dmenuPathOk("/run/user/1/marchyo/menu/req-1.json", "/run/user/1"));
  assert.ok(!R.dmenuPathOk("/run/user/1/marchyo/menu/../x.json", "/run/user/1"));
  assert.ok(!R.dmenuPathOk("/tmp/marchyo/menu/req.json", "/run/user/1"));
  assert.ok(!R.dmenuPathOk("/run/user/1/marchyo/menu/req.txt", "/run/user/1"));
  assert.ok(!R.dmenuPathOk("/marchyo/menu/req.json", ""));
});

// omarchy's MenuModel.dmenuValue and its single-select answer, copied here so
// the round trip is checked against the plugin's own rules.
const omarchyValue = (option) => {
  const parts = String(option).split("\t");
  if (parts.length > 1) parts.shift();
  return parts.join("\t");
};

test("rows become options whose value matches the native answer", () => {
  const rows = [
    { label: "a" },
    { glyph: "G", label: "b" },
    { label: "c", subtext: "s" },
    { glyph: "G", label: "d", subtext: "t" },
  ];
  const native = rows.map((r) => (r.subtext ? r.label + "\t" + r.subtext : r.label));
  assert.deepEqual(rows.map(R.optionOf).map(omarchyValue), native);
});

test("a select request maps to the omarchy payload", () => {
  const p = R.dmenuPayload(
    {
      mode: "select",
      prompt: "Pick",
      rows: [{ label: "a" }, { nope: 1 }, { label: "b", subtext: "x" }],
      multiple: true,
      selected: ["a"],
      width: 400,
      maxHeight: 300,
      onChange: ["marchyo", "x"],
      changeKey: "k",
    },
    "/run/user/1/marchyo/menu/req-1.json",
  );
  assert.deepEqual(p, {
    mode: "select",
    prompt: "Pick",
    options: ["a", "\tb\tx"],
    multiple: true,
    selected: ["a"],
    selectionFile: "/run/user/1/marchyo/menu/req-1.out",
    doneFile: "/run/user/1/marchyo/menu/req-1.done",
    width: 400,
    maxHeight: 300,
    onChange: ["marchyo", "x"],
    changeKey: "k",
  });
});

test("an input request and an unreadable request", () => {
  const p = R.dmenuPayload({ mode: "input", prompt: "Name" }, "/r/marchyo/menu/q.json");
  assert.equal(p.mode, "input");
  assert.deepEqual(p.options, []);
  assert.equal(p.multiple, false);
  const q = R.dmenuPayload(null, "/r/marchyo/menu/q.json");
  assert.equal(q.mode, "select");
  assert.equal(q.doneFile, "/r/marchyo/menu/q.done");
});

console.log(`launcher-routes: ${passed} passed`);
