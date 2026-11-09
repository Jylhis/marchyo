"use strict";
const assert = require("node:assert/strict");
const M = require("../../shell/Commons/KeyboardLayoutModel.js");

for (const name of ["power-button", "sleep-button", "lid-switch", "video-bus",
  "hl-virtual-keyboard", "asus-wmi-hotkeys-2", "intel-wireless-radio-control"])
  assert.equal(M.isTypedKeyboard(name), false, name);
assert.equal(M.isTypedKeyboard("usb-keyboard"), true);
assert.equal(M.isTypedKeyboard(""), false);
const main = { name: "power-button", main: true, layout: "us,de" };
const first = { name: "usb-keyboard", layout: "us,de", active_keymap: "English (US)" };
const second = { name: "bluetooth-keyboard", layout: "fi", active_keymap: "Finnish" };
assert.equal(M.selectKeyboard([main, first, second]), first);
assert.equal(M.selectKeyboard([main, first, second], second.name), second);
assert.equal(M.selectKeyboard([main]), undefined);
assert.equal(M.hasMultipleLayouts(first), true);
assert.equal(M.hasMultipleLayouts(second), false);
assert.equal(M.hasMultipleLayouts({ layout: "us," }), false);
assert.equal(M.eventKeyboard("usb-keyboard,English (US, intl.)"), first.name);
assert.equal(M.eventKeyboard("hl-virtual-keyboard,English (US)"), "");
console.log("keyboard-layout-model: passed");
