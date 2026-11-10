const assert = require("node:assert/strict");
const { ignoreRepeat } = require("../../shell/Commons/SessionLock.js");

assert.equal(ignoreRepeat(true, false), true);
assert.equal(ignoreRepeat(true, true), false);
assert.equal(ignoreRepeat(false, false), false);
assert.equal(ignoreRepeat(false, true), false);
