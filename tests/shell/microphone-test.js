"use strict";
const assert = require("node:assert/strict");
const M = require("../../shell/Commons/Microphone.js");
const capture = { name: "browser", properties: { "application.name": "Browser" },
  audio: { muted: false } };
assert.equal(M.isCapture(capture), true);
assert.equal(M.isCapture({ ...capture, audio: { muted: true } }), false);
assert.equal(M.isCapture({ ...capture, properties: { "application.name": "Quickshell Peak Detect" } }),
  false);
assert.equal(M.isCapture({ ...capture, name: "quickshell-peak-monitor" }), false);
assert.equal(M.isCapture({ ...capture, properties: null }), false);
assert.equal(M.isCapture(null), false);
assert.equal(M.steppedVolume(0.98, 120), 1);
assert.equal(M.steppedVolume(0.02, -120), 0);
assert.equal(M.steppedVolume(0.5, 120), 0.55);
assert.equal(M.steppedVolume(0.5, -120), 0.45);
assert.equal(M.steppedVolume(0.5, 0), 0.5);
console.log("microphone: passed");
