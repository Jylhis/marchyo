// Unit tests for shell/Commons/Speedtest.js, the speed test parsers.
//
// Run: node tests/shell/speedtest-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const S = require(path.join(__dirname, "..", "..", "shell", "Commons", "Speedtest.js"));

function test(name, fn) {
  try {
    fn();
  } catch (error) {
    console.error("not ok - " + name);
    console.error(String(error.message).replace(/^/gm, "    "));
    process.exit(1);
  }
  console.log("ok - " + name);
}

test("curl speeds convert bytes per second to megabits per second", () => {
  assert.equal(S.mbpsFromCurl("12500000"), 100);
  assert.equal(S.mbpsFromCurl(" 125000.000 \n"), 1);
  assert.equal(S.mbpsFromCurl("0"), -1);
  assert.equal(S.mbpsFromCurl("n/a"), -1);
  assert.equal(S.mbpsFromCurl(undefined), -1);
});

test("curl latency converts seconds to whole milliseconds", () => {
  assert.equal(S.pingMsFromCurl("0.0234"), 23);
  assert.equal(S.pingMsFromCurl("0.0001"), 1);
  assert.equal(S.pingMsFromCurl("0.000000"), -1);
  assert.equal(S.pingMsFromCurl(""), -1);
});

test("dd summary lines give MB/s in every unit", () => {
  const line = (rate) => "536870912 bytes (537 MB, 512 MiB) copied, 0.4 s, " + rate;
  assert.equal(S.mbPerSecFromDd(line("1.3 GB/s")), 1300);
  assert.equal(S.mbPerSecFromDd(line("420 MB/s")), 420);
  assert.equal(S.mbPerSecFromDd(line("900 kB/s")), 0.9);
  assert.equal(S.mbPerSecFromDd(line("1,5 GB/s")), 1500);
  assert.equal(Math.round(S.mbPerSecFromDd(line("100 MiB/s")) * 10) / 10, 104.9);
  assert.equal(S.mbPerSecFromDd("dd: failed to open"), -1);
  assert.equal(S.mbPerSecFromDd(undefined), -1);
});

test("rates format with one decimal below 10 and a dash when unknown", () => {
  assert.equal(S.formatMbps(123.4), "123 Mbit/s");
  assert.equal(S.formatMbps(0.84), "0.8 Mbit/s");
  assert.equal(S.formatMbps(-1), "-");
  assert.equal(S.formatMBps(1300), "1300 MB/s");
  assert.equal(S.formatMs(23), "23 ms");
  assert.equal(S.formatMs(-1), "-");
});

console.log("speedtest tests passed");
