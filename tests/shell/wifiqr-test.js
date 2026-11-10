"use strict";
const assert = require("node:assert/strict");
const Q = require("../../shell/Commons/WifiQr.js");
assert.equal(Q.payload("Cafe;Guest", "", ""), "WIFI:T:nopass;S:Cafe\\;Guest;;");
assert.equal(
  Q.payload("Cafe", "wpa-psk", "a:b\\c"),
  "WIFI:T:WPA;S:Cafe;P:a\\:b\\\\c;;",
);
assert.equal(
  Q.payload("Cafe", "sae", "secret"),
  "WIFI:T:WPA;S:Cafe;P:secret;;",
);
assert.equal(Q.payload("Cafe", "wpa-psk", ""), "");
assert.equal(Q.payload("Cafe", "wpa-eap", ""), "");
assert.equal(Q.payload("", "", ""), "");
const rows = Array(29).fill("  ".repeat(29));
rows[4] = "  ".repeat(4) + "##" + "  ".repeat(24);
assert.deepEqual(Q.parseAscii(rows.join("\n") + "\n"), {
  size: 29,
  cells: [{ x: 4, y: 4 }],
});
assert.equal(Q.parseAscii(rows.slice(1).join("\n")).size, 0);
assert.equal(Q.parseAscii(rows.join("\n").replace("##", "# ")).size, 0);
assert.equal(Q.parseAscii("").size, 0);
console.log("wifiqr: passed");
