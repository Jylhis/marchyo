// Unit tests for shell/Commons/Format.js — the shell's pure parsing logic.
//
// The rest of the shell is QML, which can only be exercised by starting
// Quickshell against a Qt platform plugin, so `nix flake check` cannot reach it
// (`just -f shell/Justfile check` covers that, on a machine that has Quickshell).
// Keeping the parsing in a plain JavaScript module with a CommonJS guard buys
// headless coverage of the part most likely to be wrong: field splitting and
// fallbacks over the text of external tools.
//
// Run: node tests/shell/format-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const modulePath = path.join(__dirname, "..", "..", "shell", "Commons", "Format.js");
const Format = require(modulePath);

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

// ── the guard itself ─────────────────────────────────────────────────────────

// A test suite that silently stops testing the real thing is worse than no
// suite. If the CommonJS guard is dropped (or the module gains a `.pragma
// library` line, which QML accepts and Node rejects) the require above would
// fail outright — but an *empty* export object would let every test below pass
// vacuously, so pin the surface explicitly.
test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(Format).sort(), [
    "fmtWatts",
    "parseDeviceAddress",
    "parseDeviceShow",
    "shortCode",
    "splitTerse",
    "supplyWatts",
    "throttleWarnings",
  ]);
});

// ── shortCode ────────────────────────────────────────────────────────────────

test("shortCode maps the known keymaps to waybar's short codes", () => {
  assert.equal(Format.shortCode("English (US)"), "us");
  assert.equal(Format.shortCode("English (UK)"), "gb");
  assert.equal(Format.shortCode("Finnish"), "fi");
  assert.equal(Format.shortCode("Norwegian"), "no");
});

test("shortCode falls back to the first word, lowercased and clipped to three", () => {
  assert.equal(Format.shortCode("Czech"), "cze");
  assert.equal(Format.shortCode("Portuguese (Brazil)"), "por");
  // The clip is what keeps an unknown layout from widening the bar.
  assert.equal(Format.shortCode("Serbian (Latin)").length, 3);
});

test("shortCode returns empty for no layout, so the widget can stay hidden", () => {
  // KeyboardLayoutWidget binds `shown` to this being non-empty; a placeholder
  // here would put a stray label in the bar before the first probe answers.
  assert.equal(Format.shortCode(""), "");
  assert.equal(Format.shortCode(null), "");
  assert.equal(Format.shortCode(undefined), "");
});

test("shortCode does not resolve inherited Object properties as keymaps", () => {
  // A plain `map[keymap] !== undefined` lookup answers "constructor" and
  // "toString" with a function, which QML would then render into the bar.
  assert.equal(Format.shortCode("constructor"), "con");
  assert.equal(Format.shortCode("toString"), "tos");
});

// ── splitTerse ───────────────────────────────────────────────────────────────

test("splitTerse honours nmcli's backslash escaping", () => {
  // nmcli -t escapes a literal colon inside a value. Splitting on a bare ":"
  // tears "Cafe: Free" apart and reads its second half as the next field.
  assert.deepEqual(Format.splitTerse("yes:Cafe\\: Free:73"), ["yes", "Cafe: Free", "73"]);
  assert.deepEqual(Format.splitTerse("a\\\\b:c"), ["a\\b", "c"]);
});

test("splitTerse keeps trailing empty fields", () => {
  // "lo:unmanaged:" is a device with no address; dropping the empty tail would
  // make the record look too short to classify.
  assert.deepEqual(Format.splitTerse("lo:unmanaged:"), ["lo", "unmanaged", ""]);
});

// ── parseDeviceShow / parseDeviceAddress ─────────────────────────────────────

// Verbatim `nmcli -t -f GENERAL.DEVICE,GENERAL.STATE,IP4.ADDRESS device show`
// output, captured from a wired host. The previous fixtures here encoded a
// one-record-per-line "DEVICE:STATE:ADDR" shape that no nmcli subcommand emits,
// which is why these tests stayed green while the bar showed "offline": note
// the numeric state prefix, the indexed address key, the blank-line block
// separator, and tailscale0 omitting the address line entirely.
const DEVICE_SHOW = [
  "GENERAL.DEVICE:enp12s0",
  "GENERAL.STATE:100 (connected)",
  "IP4.ADDRESS[1]:10.104.35.92/23",
  "",
  "GENERAL.DEVICE:lo",
  "GENERAL.STATE:100 (connected (externally))",
  "IP4.ADDRESS[1]:127.0.0.1/8",
  "",
  "GENERAL.DEVICE:tailscale0",
  "GENERAL.STATE:10 (unmanaged)",
  "",
].join("\n");

test("parseDeviceAddress reads real `nmcli device show` output", () => {
  assert.deepEqual(Format.parseDeviceAddress(DEVICE_SHOW), {
    ifName: "enp12s0",
    ipAddress: "10.104.35.92",
  });
});

test("parseDeviceShow keeps one record per device, in nmcli's order", () => {
  assert.deepEqual(Format.parseDeviceShow(DEVICE_SHOW), [
    { ifName: "enp12s0", state: "100 (connected)", ipAddress: "10.104.35.92" },
    { ifName: "lo", state: "100 (connected (externally))", ipAddress: "127.0.0.1" },
    { ifName: "tailscale0", state: "10 (unmanaged)", ipAddress: "" },
  ]);
});

test("parseDeviceAddress skips loopback even when it is listed first", () => {
  const show = [
    "GENERAL.DEVICE:lo",
    "GENERAL.STATE:100 (connected (externally))",
    "IP4.ADDRESS[1]:127.0.0.1/8",
    "",
    "GENERAL.DEVICE:wlan0",
    "GENERAL.STATE:100 (connected)",
    "IP4.ADDRESS[1]:192.168.1.10/24",
  ].join("\n");
  assert.deepEqual(Format.parseDeviceAddress(show), { ifName: "wlan0", ipAddress: "192.168.1.10" });
});

test("parseDeviceAddress skips a connected device that has no address line", () => {
  const show = [
    "GENERAL.DEVICE:tun0",
    "GENERAL.STATE:100 (connected)",
    "",
    "GENERAL.DEVICE:wlan0",
    "GENERAL.STATE:100 (connected)",
    "IP4.ADDRESS[1]:10.0.0.5/8",
  ].join("\n");
  assert.deepEqual(Format.parseDeviceAddress(show), { ifName: "wlan0", ipAddress: "10.0.0.5" });
});

test("parseDeviceAddress prefers a managed device over an externally-managed bridge", () => {
  const show = [
    "GENERAL.DEVICE:podman0",
    "GENERAL.STATE:100 (connected (externally))",
    "IP4.ADDRESS[1]:10.88.0.1/16",
    "",
    "GENERAL.DEVICE:enp1s0",
    "GENERAL.STATE:100 (connected)",
    "IP4.ADDRESS[1]:192.168.1.20/24",
  ].join("\n");
  assert.deepEqual(Format.parseDeviceAddress(show), { ifName: "enp1s0", ipAddress: "192.168.1.20" });
});

test("parseDeviceAddress falls back to an externally-managed device", () => {
  // systemd-networkd hosts: NetworkManager only observes the uplink, so
  // "connected (externally)" is the best address available.
  const show = [
    "GENERAL.DEVICE:enp1s0",
    "GENERAL.STATE:100 (connected (externally))",
    "IP4.ADDRESS[1]:192.168.1.20/24",
  ].join("\n");
  assert.deepEqual(Format.parseDeviceAddress(show), { ifName: "enp1s0", ipAddress: "192.168.1.20" });
});

test("parseDeviceAddress returns empties when nothing is connected", () => {
  const empty = { ifName: "", ipAddress: "" };
  const show = [
    "GENERAL.DEVICE:enp1s0",
    "GENERAL.STATE:30 (disconnected)",
    "",
    "GENERAL.DEVICE:tailscale0",
    "GENERAL.STATE:10 (unmanaged)",
  ].join("\n");
  assert.deepEqual(Format.parseDeviceAddress(show), empty);
  assert.deepEqual(Format.parseDeviceAddress(""), empty);
  assert.deepEqual(Format.parseDeviceAddress(null), empty);
  // `device status` rejects the IP4.ADDRESS field: nmcli exits 2 and prints
  // nothing. Empties, never a wrong answer.
  assert.deepEqual(Format.parseDeviceAddress("\n"), empty);
});

// ── power ────────────────────────────────────────────────────────────────────

test("fmtWatts prints one decimal and drops near-zero readings", () => {
  assert.equal(Format.fmtWatts(12.34), "12.3 W");
  assert.equal(Format.fmtWatts(-8.06), "8.1 W");
  assert.equal(Format.fmtWatts(0.01), "");
  assert.equal(Format.fmtWatts(undefined), "");
});

test("supplyWatts rates an online USB-C supply from its max voltage and current", () => {
  const ucsi = [
    "POWER_SUPPLY_NAME=ucsi-source-psy-USBC000:001",
    "POWER_SUPPLY_TYPE=USB",
    "POWER_SUPPLY_ONLINE=1",
    "POWER_SUPPLY_VOLTAGE_MAX=20000000",
    "POWER_SUPPLY_CURRENT_MAX=3250000",
  ].join("\n");
  assert.equal(Format.supplyWatts(ucsi), 65);
  assert.equal(Format.supplyWatts(ucsi.replace("ONLINE=1", "ONLINE=0")), 0);
});

test("supplyWatts reads 0 for plain Mains adapters, batteries and empty input", () => {
  const mains = ["POWER_SUPPLY_NAME=AC", "POWER_SUPPLY_TYPE=Mains", "POWER_SUPPLY_ONLINE=1"].join("\n");
  const battery = [
    "POWER_SUPPLY_TYPE=Battery",
    "POWER_SUPPLY_ONLINE=1",
    "POWER_SUPPLY_VOLTAGE_MAX=17000000",
    "POWER_SUPPLY_CURRENT_MAX=3000000",
  ].join("\n");
  assert.equal(Format.supplyWatts(mains), 0);
  assert.equal(Format.supplyWatts(battery), 0);
  assert.equal(Format.supplyWatts(""), 0);
  assert.equal(Format.supplyWatts(null), 0);
});

test("throttleWarnings lists every active signal", () => {
  assert.deepEqual(
    Format.throttleWarnings({ degradation: "heat", throttleDelta: 3, scalingMaxKhz: 2400000, cpuinfoMaxKhz: 4700000 }),
    ["High temperature: performance limited", "CPU thermal throttling", "CPU capped at 2.4 GHz (max 4.7 GHz)"],
  );
  assert.deepEqual(Format.throttleWarnings({ degradation: "lap" }), ["Lap detected: performance limited"]);
});

test("throttleWarnings stays silent when nothing is throttled or a source is missing", () => {
  assert.deepEqual(
    Format.throttleWarnings({ degradation: "", throttleDelta: 0, scalingMaxKhz: 4700000, cpuinfoMaxKhz: 4700000 }),
    [],
  );
  assert.deepEqual(Format.throttleWarnings({ degradation: "", throttleDelta: NaN, scalingMaxKhz: NaN, cpuinfoMaxKhz: NaN }), []);
});

console.log("# " + passed + " passed");
