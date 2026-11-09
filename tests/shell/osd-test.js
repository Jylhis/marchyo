"use strict";

const assert = require("node:assert/strict");
const {iconFor} = require("../../shell/Commons/OsdModel.js");

assert.equal(iconFor("volume", 0), iconFor("mute", 0));
assert.equal(iconFor("volume", 1), iconFor("volume", 33));
assert.notEqual(iconFor("volume", 33), iconFor("volume", 34));
assert.equal(iconFor("volume", 34), iconFor("volume", 66));
assert.notEqual(iconFor("volume", 66), iconFor("volume", 67));
assert.equal(iconFor("volume", 67), iconFor("volume", 150));
assert.notEqual(iconFor("mic", 0), iconFor("micMute", 0));
assert.ok(iconFor("brightness", 100));
assert.equal(iconFor("unknown", 100), "");
console.log("OSD: level, mute, mic and brightness icons passed");
