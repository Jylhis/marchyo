// Unit tests for shell/Commons/OmarchyMenu.js: the command menu tree, with its
// menu.local.json overlay, rendered as omarchy's omarchy-menu.jsonc.
//
// Run: node tests/shell/omarchy-menu-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Commons = path.join(__dirname, "..", "..", "shell", "Commons");
const MenuModel = require(path.join(Commons, "MenuModel.js"));
const OM = require(path.join(Commons, "OmarchyMenu.js"));

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

const base = {
  apps: { label: "Apps", icon: "applications-all", order: 10, action: "provider", provider: "apps" },
  capture: { label: "Capture", icon: "camera-photo", order: 20 },
  "capture.screenshot": {
    label: "Screenshot",
    icon: "camera-photo",
    order: 10,
    action: "exec",
    target: "sleep 0.2; marchyo capture screenshot",
    aliases: ["screen shot", "screengrab"],
    when: null
  },
  "capture.annotate": { label: "Annotate", icon: "draw-freehand", order: 20, action: "exec", target: "true" },
  "capture.record": {
    label: "Record",
    icon: "media-record",
    order: 30,
    action: "exec",
    target: "marchyo capture record",
    when: "! pgrep -f gpu-screen-recorder >/dev/null"
  },
  toggle: { label: "Toggle", order: 30 },
  "toggle.nightlight": {
    label: "Nightlight",
    order: 10,
    action: "exec",
    target: "marchyo toggle nightlight",
    checked: "test \"$(marchyo toggle nightlight --status)\" = on"
  },
  hardware: { label: "Hardware", order: 40 },
  "hardware.bluetooth": { label: "Bluetooth", icon: "bluetooth", order: 10, action: "terminal", target: "bluetui" },
  appearance: { label: "Appearance", order: 50 },
  "appearance.theme": { label: "Theme", order: 10, action: "provider", provider: "themes" },
  "appearance.font": { label: "Font", order: 20, action: "provider", provider: "fonts" },
  "appearance.picker": { label: "Picker", order: 30, action: "launcher", target: "emoji" },
  system: { label: "System", order: 60 },
  "system.reboot": { label: "Reboot", order: 10, action: "exec", target: "marchyo reboot" },
  setup: { label: "Setup", order: 70 },
  "setup.keys": { label: "Keys", icon: "input-keyboard", order: 10, action: "launcher", target: "keys" }
};

const sheet = [
  { combo: "SUPER + K", description: "Keybindings cheat sheet", group: "Session", dispatch: "hl.dsp.global(\"marchyo:launcher.keys\")" },
  { combo: "SUPER + C", description: "Copy", group: "Clipboard", dispatch: null }
];

const render = (overlay) =>
  JSON.parse(OM.render(MenuModel.build(MenuModel.mergeOverlay(base, overlay || {})), sheet));
const ids = (overlay) => OM.rows(MenuModel.build(MenuModel.mergeOverlay(base, overlay || {})), sheet).map((r) => r[0]);

test("rows follow the tree order with the cheat sheet under setup.keys", () => {
  assert.deepEqual(ids(), [
    "apps",
    "capture",
    "capture.screenshot",
    "capture.annotate",
    "capture.record",
    "toggle",
    "toggle.nightlight",
    "hardware",
    "hardware.bluetooth",
    "appearance",
    "appearance.theme",
    "appearance.font",
    "appearance.picker",
    "system",
    "system.reboot",
    "setup",
    "setup.keys",
    "setup.keys.001",
    "setup.keys.002"
  ]);
});

test("each action kind maps onto omarchy's row fields", () => {
  const p = render();
  assert.equal(p.apps.provider, "apps");
  assert.equal(p["capture.screenshot"].action, "sleep 0.2; marchyo capture screenshot");
  assert.deepEqual(p["capture.screenshot"].searchTerms, ["screen shot", "screengrab"]);
  assert.equal(p["capture.screenshot"].when, undefined);
  assert.equal(p["capture.record"].when, "! pgrep -f gpu-screen-recorder >/dev/null");
  assert.ok(p["toggle.nightlight"].checked.startsWith("test \"$(marchyo toggle nightlight"));
  assert.equal(p["toggle.nightlight"].icon, undefined);
  assert.equal(p["hardware.bluetooth"].action, "marchyo launch floating-terminal sh -c bluetui");
  assert.equal(p["appearance.theme"].action, "marchyo shell open themes");
  assert.equal(p["appearance.font"].provider, "fonts");
  assert.equal(p["appearance.picker"].action, "marchyo shell launcher emoji");
  assert.equal("action" in p.capture, false);
  assert.deepEqual(p["setup.keys"].aliases, ["keys"]);
  assert.equal(p["setup.keys.001"].action, "sleep 0.2; hyprctl dispatch 'hl.dsp.global(\"marchyo:launcher.keys\")'");
  assert.equal(p["setup.keys.002"].action, ":");
  assert.equal(p["capture.screenshot"].icon, OM.glyph("camera-photo"));
  assert.notEqual(p["capture.screenshot"].icon, "");
});

test("the menu.local.json overlay retitles, adds, disables and removes rows", () => {
  const overlay = {
    "capture.annotate": { label: "Draw" },
    "capture.ocr": { label: "OCR", order: 25, action: "exec", target: "marchyo capture ocr" },
    system: { disabled: true },
    "toggle.nightlight": null
  };
  const p = render(overlay);
  assert.equal(p["capture.annotate"].label, "Draw");
  assert.equal(p["capture.annotate"].action, "true");
  assert.equal(p["capture.ocr"].action, "marchyo capture ocr");
  assert.equal("system" in p, false);
  assert.equal("system.reboot" in p, false);
  assert.equal("toggle.nightlight" in p, false);
  const order = ids(overlay);
  assert.ok(order.indexOf("capture.annotate") < order.indexOf("capture.ocr"));
  assert.ok(order.indexOf("capture.ocr") < order.indexOf("capture.record"));
});

test("shell quoting and glyphs", () => {
  assert.equal(OM.shellArg("bluetui"), "bluetui");
  assert.equal(OM.shellArg("a b"), "'a b'");
  assert.equal(OM.shellArg("it's"), "'it'\\''s'");
  assert.equal(OM.glyph("no-such-icon"), "");
  assert.equal(OM.glyph("x"), "");
  assert.equal(OM.glyph("★"), "★");
  assert.equal(OM.glyph(""), "");
});

test("an empty tree renders an empty object", () => {
  assert.deepEqual(JSON.parse(OM.render(MenuModel.build({}), [])), {});
});

console.log("# " + passed + " passed");
