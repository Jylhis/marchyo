"use strict";
const assert = require("node:assert/strict");
const D = require("../../shell/Commons/Displays.js");
const rects = [
  { name: "a", x: 0, y: 0, w: 100, h: 80 },
  { name: "b", x: 100, y: 0, w: 200, h: 100 },
];
assert.deepEqual(D.placeBeside(rects, "a", "b", true), [
  { name: "a", x: 200, y: 0, w: 100, h: 80 },
  { name: "b", x: 0, y: 0, w: 200, h: 100 },
]);
assert.deepEqual(D.placeBeside(rects, "a", "b", false), rects);
assert.equal(D.placeBeside(rects, "a", "a", false), null);
assert.equal(D.placeBeside(rects, "missing", "a", false), null);
assert.equal(
  D.placeBeside(
    rects.concat([{ name: "c", x: 300, y: 0, w: 100, h: 100 }]),
    "a",
    "b",
    true,
  ),
  null,
);
assert.equal(rects[0].x, 0);
const displays = [
  { name: "a", enabled: true, internal: true, mirrorOf: "" },
  { name: "b", enabled: true, internal: false, mirrorOf: "a" },
];
assert.equal(D.mirrorMatches(displays, true), true);
assert.equal(D.mirrorMatches(displays, false), false);
assert.equal(D.mirrorMatches([], false), false);
displays[1].mirrorOf = "";
assert.equal(D.mirrorMatches(displays, false), true);
displays.push({ name: "c", enabled: true, internal: false, mirrorOf: "a" });
assert.equal(D.mirrorMatches(displays, true), false);
console.log("display panel: passed");
