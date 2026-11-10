"use strict";
const assert = require("node:assert/strict");
const B = require("../../shell/Commons/Battery.js");
let notified = false;
function sample(level, discharging = true, charging = false, present = true) {
  const state = B.warningState(
    present,
    level,
    discharging,
    charging,
    10,
    notified,
  );
  notified = state.notified;
  return state.notify;
}
assert.equal(sample(11), false);
assert.equal(sample(10), true);
assert.equal(sample(5), false);
assert.equal(sample(5, false, false, false), false);
assert.equal(notified, true);
assert.equal(sample(5, false, true), false);
assert.equal(notified, false);
assert.equal(sample(5), true);
assert.equal(sample(11), false);
assert.equal(notified, false);
assert.equal(sample(10, false), false);
assert.equal(sample(10), true);
assert.equal(B.warningState(true, 10, true, false, 10, true).notify, false);
for (const value of [undefined, null, "5", -1, 101, NaN])
  assert.equal(B.warningThreshold(value), 10);
assert.equal(B.warningThreshold(5), 5);
assert.equal(B.warningThreshold(0), 0);
console.log("battery warning: passed");
