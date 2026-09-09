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
    "parseDeviceAddress",
    "parseDeviceShow",
    "parseWifi",
    "shortCode",
    "splitTerse",
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
  // KeyboardLayoutWidget binds `visible` to this being non-empty; a placeholder
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

// ── parseWifi ────────────────────────────────────────────────────────────────

test("parseWifi returns the active network, not the first one listed", () => {
  const wifi = Format.parseWifi(["no:Neighbour:88", "yes:Home:61", "no:Other:40"].join("\n"));
  assert.deepEqual(wifi, { ssid: "Home", signal: 61 });
});

test("parseWifi keeps a colon inside an SSID", () => {
  assert.deepEqual(Format.parseWifi("yes:Cafe\\: Free:73"), { ssid: "Cafe: Free", signal: 73 });
});

test("parseWifi reports no reading rather than 0% when the signal is unusable", () => {
  // NetworkWidget renders `signal` as a percentage; -1 is the "unknown" the bar
  // already understands, while 0 would draw a full-strength-looking empty bar.
  assert.equal(Format.parseWifi("yes:Home:").signal, -1);
  assert.equal(Format.parseWifi("yes:Home:not-a-number").signal, -1);
});

test("parseWifi returns empties when nothing is active or the output is junk", () => {
  const empty = { ssid: "", signal: -1 };
  assert.deepEqual(Format.parseWifi("no:Home:61\nno:Other:40"), empty);
  assert.deepEqual(Format.parseWifi(""), empty);
  assert.deepEqual(Format.parseWifi(null), empty);
  // A truncated read must mean "no data", never a wrong answer.
  assert.deepEqual(Format.parseWifi("ye"), empty);
});

test("parseWifi does not mistake an SSID of 'yes' for the active marker", () => {
  assert.deepEqual(Format.parseWifi("no:yes:61"), { ssid: "", signal: -1 });
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

console.log("# " + passed + " passed");
