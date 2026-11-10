// Unit tests for shell/Commons/Connectivity.js, the NetworkManager
// connectivity helpers behind Services/NetworkStatus.
//
// Run: node tests/shell/connectivity-test.js

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Connectivity = require(path.join(__dirname, "..", "..", "shell", "Commons", "Connectivity.js"));

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
}

const ENUM = { Unknown: 0, None: 1, Portal: 2, Limited: 3, Full: 4 };

test("fromEnum names each member of the enum object", () => {
  for (const name of Object.keys(ENUM))
    assert.equal(Connectivity.fromEnum(ENUM[name], ENUM), name);
});

test("fromEnum falls back to Unknown", () => {
  assert.equal(Connectivity.fromEnum(99, ENUM), "Unknown");
  assert.equal(Connectivity.fromEnum(2, undefined), "Unknown");
  assert.equal(Connectivity.fromEnum(undefined, ENUM), "Unknown");
});

test("isRestricted is true for Portal and Limited only", () => {
  assert.equal(Connectivity.isRestricted("Portal"), true);
  assert.equal(Connectivity.isRestricted("Limited"), true);
  for (const name of ["Full", "None", "Unknown"])
    assert.equal(Connectivity.isRestricted(name), false);
});

console.log("connectivity-test: " + passed + " passed");
