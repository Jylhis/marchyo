// Unit tests for shell/Commons/Elsewhen.js: offsets, clock formatting, geocoder
// and forecast parsing, and the persisted city list.
//
// Run: node tests/shell/elsewhen-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const shellDir = path.join(__dirname, "..", "..", "shell");
const E = require(path.join(shellDir, "Commons", "Elsewhen.js"));

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

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(E).sort(), [
    "dayDelta",
    "defaultState",
    "formatClock",
    "formatTemp",
    "geocodeUrl",
    "isDaytime",
    "normalizeState",
    "offsetLabel",
    "parseGeocode",
    "parseOffsetMinutes",
    "parseOffsets",
    "parseWeather",
    "project",
    "relativeOffset",
    "validZone",
    "weatherUrl",
    "weekdayShort",
    "withCity",
    "withHome",
    "withPeople",
    "withToggle",
    "withoutCity",
    "zoneParts",
  ]);
});

test("zone names are validated before they reach the date probe", () => {
  assert.equal(E.validZone("Europe/Helsinki"), true);
  assert.equal(E.validZone("America/Argentina/Buenos_Aires"), true);
  assert.equal(E.validZone("Etc/GMT+5"), true);
  assert.equal(E.validZone("UTC"), true);
  assert.equal(E.validZone("../etc/passwd"), false);
  assert.equal(E.validZone("a b"), false);
  assert.equal(E.validZone("$(id)"), false);
  assert.equal(E.validZone(""), false);
  assert.equal(E.validZone(null), false);
});

test("parseOffsetMinutes reads date +%z", () => {
  assert.equal(E.parseOffsetMinutes("+0000"), 0);
  assert.equal(E.parseOffsetMinutes("+0530"), 330);
  assert.equal(E.parseOffsetMinutes("-0800"), -480);
  assert.equal(E.parseOffsetMinutes("+0545"), 345);
  assert.equal(E.parseOffsetMinutes("garbage"), null);
});

test("parseOffsets maps one line per zone and skips bad lines", () => {
  const out = E.parseOffsets("+0200 EET\n-0500 EST\nnope\n", ["Europe/Helsinki", "America/New_York", "Bad/Zone"]);
  assert.deepEqual(out, {
    "Europe/Helsinki": { min: 120, abbr: "EET" },
    "America/New_York": { min: -300, abbr: "EST" },
  });
  assert.deepEqual(E.parseOffsets("", ["Asia/Tokyo"]), {});
});

test("offsetLabel and relativeOffset render half-hour zones", () => {
  assert.equal(E.offsetLabel(0), "UTC");
  assert.equal(E.offsetLabel(330), "UTC+5:30");
  assert.equal(E.offsetLabel(-480), "UTC-8");
  assert.equal(E.offsetLabel(345), "UTC+5:45");
  assert.equal(E.relativeOffset(180, 0), "+3h");
  assert.equal(E.relativeOffset(0, 330), "-5h30");
  assert.equal(E.relativeOffset(60, 60), "0h");
  assert.equal(E.relativeOffset(65, 0), "+1h05");
});

test("zoneParts shifts the instant into the zone's wall clock", () => {
  const now = Date.UTC(2026, 10, 5, 22, 30);
  const tokyo = E.zoneParts(now, 540);
  assert.deepEqual([tokyo.year, tokyo.month, tokyo.day, tokyo.hour, tokyo.minute], [2026, 11, 6, 7, 30]);
  const la = E.zoneParts(now, -480);
  assert.deepEqual([la.day, la.hour], [5, 14]);
  assert.equal(E.weekdayShort(tokyo), "Fri");
});

test("formatClock honours the 12/24 hour toggle", () => {
  const at = (hour, minute) => ({ hour, minute });
  assert.equal(E.formatClock(at(0, 5), true), "00:05");
  assert.equal(E.formatClock(at(0, 5), false), "12:05 AM");
  assert.equal(E.formatClock(at(12, 0), false), "12:00 PM");
  assert.equal(E.formatClock(at(15, 9), false), "3:09 PM");
  assert.equal(E.formatClock(at(15, 9), true), "15:09");
});

test("dayDelta compares calendar days across the date line", () => {
  const now = Date.UTC(2026, 10, 5, 22, 30);
  const home = E.zoneParts(now, 0);
  assert.equal(E.dayDelta(E.zoneParts(now, 540), home), 1);
  assert.equal(E.dayDelta(E.zoneParts(now, -480), home), 0);
  assert.equal(E.dayDelta(E.zoneParts(now, -1380), home), -1);
});

test("project places lat/lon on an equirectangular box", () => {
  assert.deepEqual(E.project(0, 0, 360, 180), { x: 180, y: 90 });
  assert.deepEqual(E.project(90, -180, 360, 180), { x: 0, y: 0 });
  assert.deepEqual(E.project(-90, 180, 720, 360), { x: 720, y: 360 });
});

test("geocodeUrl encodes the query", () => {
  const url = E.geocodeUrl("São Paulo & co", 3);
  assert.ok(url.startsWith("https://geocoding-api.open-meteo.com/v1/search?count=3"));
  assert.ok(url.endsWith("name=S%C3%A3o%20Paulo%20%26%20co"));
});

test("parseGeocode keeps valid places and drops the rest", () => {
  const text = JSON.stringify({
    results: [
      { name: "Oakland", admin1: "California", country_code: "US", latitude: 37.8, longitude: -122.27, timezone: "America/Los_Angeles" },
      { name: "NoZone", latitude: 1, longitude: 2 },
      { name: "BadZone", latitude: 1, longitude: 2, timezone: "../x" },
      { name: "NoCoords", timezone: "Europe/Oslo" },
      { name: "Oslo", country_code: "NO", latitude: 59.9, longitude: 10.7, timezone: "Europe/Oslo" },
    ],
  });
  const out = E.parseGeocode(text, 5);
  assert.deepEqual(out.map((p) => p.name), ["Oakland", "Oslo"]);
  assert.equal(out[0].region, "California");
  assert.equal(out[1].region, "");
  assert.equal(E.parseGeocode(text, 1).length, 1);
});

test("parseGeocode survives malformed answers", () => {
  assert.deepEqual(E.parseGeocode("not json", 5), []);
  assert.deepEqual(E.parseGeocode("{}", 5), []);
  assert.deepEqual(E.parseGeocode('{"results":"x"}', 5), []);
  assert.deepEqual(E.parseGeocode("null", 5), []);
});

test("weatherUrl batches coordinates and parseWeather reads both shapes", () => {
  const cities = [{ lat: 1.5, lon: 2.5 }, { lat: -3, lon: 4 }];
  const url = E.weatherUrl(cities);
  assert.ok(url.includes("latitude=1.5,-3&longitude=2.5,4"));
  const many = JSON.stringify([{ current: { temperature_2m: 21.4 } }, { current: {} }]);
  assert.deepEqual(E.parseWeather(many, 2), [21.4, null]);
  assert.deepEqual(E.parseWeather(JSON.stringify({ current: { temperature_2m: -3 } }), 1), [-3]);
  assert.deepEqual(E.parseWeather("nope", 2), []);
});

test("formatTemp converts on demand", () => {
  assert.equal(E.formatTemp(21.4, false), "21°C");
  assert.equal(E.formatTemp(0, true), "32°F");
  assert.equal(E.formatTemp(null, true), "");
});

test("normalizeState falls back to the seeded list on bad input", () => {
  for (const text of ["", "garbage", "null", "{}", '{"cities":"x"}']) {
    const s = E.normalizeState(text);
    assert.equal(s.cities.length, 5);
    assert.equal(s.home, "");
    assert.equal(s.use24h, true);
  }
});

test("normalizeState sanitises a saved list", () => {
  const s = E.normalizeState(
    JSON.stringify({
      home: "Europe/Oslo",
      use24h: false,
      useF: true,
      cities: [
        { name: "Oslo", tz: "Europe/Oslo", lat: 59.9, lon: 10.7, people: ["Ada", "", 3, "Bo"] },
        { name: "Evil", tz: "$(id)" },
        { tz: "Asia/Tokyo" },
      ],
    }),
  );
  assert.equal(s.home, "Europe/Oslo");
  assert.equal(s.use24h, false);
  assert.equal(s.useF, true);
  assert.equal(s.cities.length, 1);
  assert.deepEqual(s.cities[0].people, ["Ada", "Bo"]);
});

test("state updates are pure and dedupe cities", () => {
  const base = E.defaultState();
  const before = JSON.stringify(base);
  const oslo = { name: "Oslo", tz: "Europe/Oslo", lat: 59.9, lon: 10.7 };
  const added = E.withCity(base, oslo);
  assert.equal(added.cities.length, 6);
  assert.equal(E.withCity(added, oslo).cities.length, 6);
  assert.equal(E.withCity(base, { name: "x", tz: "bad zone" }).cities.length, 5);
  assert.equal(E.withoutCity(added, 5).cities.length, 5);
  assert.equal(JSON.stringify(base), before);
});

test("withPeople splits names and withHome toggles", () => {
  const base = E.defaultState();
  const named = E.withPeople(base, 1, " Ada, Bo ,,");
  assert.deepEqual(named.cities[1].people, ["Ada", "Bo"]);
  assert.deepEqual(named.cities[0].people, []);
  const home = E.withHome(base, "Asia/Tokyo");
  assert.equal(home.home, "Asia/Tokyo");
  assert.equal(E.withHome(home, "Asia/Tokyo").home, "");
});

test("withToggle flips the 12/24h and unit flags", () => {
  const base = E.defaultState();
  assert.equal(E.withToggle(base, "use24h").use24h, false);
  assert.equal(E.withToggle(base, "useF").useF, true);
  assert.equal(base.use24h, true);
});

test("the bundled world map is a list of coordinate rings", () => {
  const world = JSON.parse(fs.readFileSync(path.join(shellDir, "Panels", "world.json"), "utf8"));
  assert.ok(Array.isArray(world) && world.length > 10);
  for (const ring of world) {
    assert.ok(ring.length >= 4 && ring.length % 2 === 0);
  }
});
