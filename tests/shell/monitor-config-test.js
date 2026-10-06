// Unit tests for shell/Commons/MonitorConfig.js: per-monitor shell.json
// resolution (global config + `monitors.<output>` override).
//
// Run: node tests/shell/monitor-config-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const modulePath = path.join(__dirname, "..", "..", "shell", "Commons", "MonitorConfig.js");
const MonitorConfig = require(modulePath);

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

const DEFAULTS = {
  left: [{ id: "d.left" }],
  center: [{ id: "d.center" }],
  right: [{ id: "d.right" }],
};

const config = {
  bar: { layout: { left: [{ id: "g.left" }], right: [{ id: "g.right" }] } },
  idle: { screensaver: 150, lock: 300 },
  caffeine: { autoVideo: true },
  custom: { a: 1, b: { c: 2 } },
  monitors: {
    "DP-1": {
      bar: { layout: { right: [{ id: "m.right" }] } },
      idle: { lock: 5 },
      caffeine: { autoVideo: false },
      custom: { b: { d: 3 } },
    },
    "HDMI-A-1": { bar: { layout: { center: [] } } },
  },
};

// ── deepMerge ────────────────────────────────────────────────────────────────

test("objects merge recursively, arrays and scalars replace", () => {
  assert.deepEqual(MonitorConfig.deepMerge({ a: { x: 1, y: [1, 2] }, s: "g" }, { a: { y: [3] }, s: "m" }), {
    a: { x: 1, y: [3] },
    s: "m",
  });
});

test("undefined override keeps the base; null replaces it", () => {
  assert.deepEqual(MonitorConfig.deepMerge({ a: 1 }, undefined), { a: 1 });
  assert.equal(MonitorConfig.deepMerge({ a: 1 }, null), null);
});

test("deepMerge does not mutate its inputs", () => {
  const base = { a: { x: 1 } };
  const over = { a: { y: 2 } };
  MonitorConfig.deepMerge(base, over);
  assert.deepEqual(base, { a: { x: 1 } });
  assert.deepEqual(over, { a: { y: 2 } });
});

// ── resolve ──────────────────────────────────────────────────────────────────

test("a monitor override replaces only its own bar section", () => {
  const r = MonitorConfig.resolve(config, "DP-1");
  assert.deepEqual(r.bar.layout.left, [{ id: "g.left" }]);
  assert.deepEqual(r.bar.layout.right, [{ id: "m.right" }]);
});

test("always-global keys ignore per-monitor values", () => {
  const r = MonitorConfig.resolve(config, "DP-1");
  assert.deepEqual(r.idle, { screensaver: 150, lock: 300 });
  assert.deepEqual(r.caffeine, { autoVideo: true });
});

test("unknown keys merge per monitor too", () => {
  assert.deepEqual(MonitorConfig.resolve(config, "DP-1").custom, { a: 1, b: { c: 2, d: 3 } });
});

test("the monitors map is not part of the resolved config", () => {
  assert.equal("monitors" in MonitorConfig.resolve(config, "DP-1"), false);
  assert.equal("monitors" in MonitorConfig.resolve(config, ""), false);
});

test("an output without an override resolves to the global config", () => {
  const r = MonitorConfig.resolve(config, "eDP-1");
  const { monitors, ...global } = config;
  assert.deepEqual(r, global);
});

test("a nested monitors key inside an override is ignored", () => {
  const c = { monitors: { "DP-1": { monitors: { "DP-1": { x: 1 } }, y: 2 } } };
  assert.deepEqual(MonitorConfig.resolve(c, "DP-1"), { y: 2 });
});

test("resolve leaves the input config unchanged", () => {
  const before = JSON.stringify(config);
  MonitorConfig.resolve(config, "DP-1");
  assert.equal(JSON.stringify(config), before);
});

test("malformed input resolves to an empty or global config", () => {
  assert.deepEqual(MonitorConfig.resolve(null, "DP-1"), {});
  assert.deepEqual(MonitorConfig.resolve({ a: 1, monitors: [] }, "DP-1"), { a: 1 });
  assert.deepEqual(MonitorConfig.resolve({ a: 1, monitors: { "DP-1": "x" } }, "DP-1"), { a: 1 });
});

// ── overrideFor ──────────────────────────────────────────────────────────────

test("overrideFor strips the always-global keys", () => {
  assert.deepEqual(Object.keys(MonitorConfig.overrideFor(config, "DP-1")).sort(), ["bar", "custom"]);
  assert.deepEqual(MonitorConfig.overrideFor(config, "missing"), {});
  assert.deepEqual(MonitorConfig.overrideFor(config, ""), {});
});

test("the always-global list is idle, caffeine, monitors", () => {
  assert.deepEqual(MonitorConfig.ALWAYS_GLOBAL, ["idle", "caffeine", "monitors"]);
});

// ── barLayout ────────────────────────────────────────────────────────────────

test("barLayout falls back per section to the defaults", () => {
  assert.deepEqual(MonitorConfig.barLayout(config, "DP-1", DEFAULTS), {
    left: [{ id: "g.left" }],
    center: [{ id: "d.center" }],
    right: [{ id: "m.right" }],
  });
});

test("an explicit empty section stays empty", () => {
  assert.deepEqual(MonitorConfig.barLayout(config, "HDMI-A-1", DEFAULTS).center, []);
});

test("no config yields the defaults", () => {
  assert.deepEqual(MonitorConfig.barLayout({}, "DP-1", DEFAULTS), DEFAULTS);
  assert.deepEqual(MonitorConfig.barLayout(null, "", DEFAULTS), DEFAULTS);
});

test("a non-array section falls back to the default", () => {
  const c = { bar: { layout: { left: "nope" } } };
  assert.deepEqual(MonitorConfig.barLayout(c, "", DEFAULTS).left, DEFAULTS.left);
});

test("missing defaults yield empty sections", () => {
  assert.deepEqual(MonitorConfig.barLayout({}, "", null), { left: [], center: [], right: [] });
});

// ── barStyle ─────────────────────────────────────────────────────────────────

test("barStyle defaults to flat", () => {
  assert.equal(MonitorConfig.barStyle({}, ""), "flat");
  assert.equal(MonitorConfig.barStyle(null, "DP-1"), "flat");
  assert.equal(MonitorConfig.barStyle(config, "DP-1"), "flat");
});

test("barStyle reads the global bar.style", () => {
  assert.equal(MonitorConfig.barStyle({ bar: { style: "segmented" } }, ""), "segmented");
  assert.equal(MonitorConfig.barStyle({ bar: { style: "segmented" } }, "DP-1"), "segmented");
});

test("a per-monitor bar.style overrides the global one for that output only", () => {
  const c = { bar: { style: "segmented" }, monitors: { "HDMI-A-1": { bar: { style: "flat" } } } };
  assert.equal(MonitorConfig.barStyle(c, "HDMI-A-1"), "flat");
  assert.equal(MonitorConfig.barStyle(c, "DP-1"), "segmented");
  const m = { monitors: { "DP-1": { bar: { style: "segmented" } } } };
  assert.equal(MonitorConfig.barStyle(m, "DP-1"), "segmented");
  assert.equal(MonitorConfig.barStyle(m, "eDP-1"), "flat");
});

test("an unknown or ill-typed bar.style falls back to flat", () => {
  assert.equal(MonitorConfig.barStyle({ bar: { style: "powerline" } }, ""), "flat");
  assert.equal(MonitorConfig.barStyle({ bar: { style: 1 } }, ""), "flat");
  assert.equal(MonitorConfig.barStyle({ bar: "segmented" }, ""), "flat");
});

test("the bar styles are flat then segmented", () => {
  assert.deepEqual(MonitorConfig.BAR_STYLES, ["flat", "segmented"]);
});

// ── module surface ───────────────────────────────────────────────────────────

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(MonitorConfig).sort(), [
    "ALWAYS_GLOBAL",
    "BAR_STYLES",
    "barLayout",
    "barStyle",
    "deepMerge",
    "overrideFor",
    "resolve",
  ]);
});

console.log("# " + passed + " passed");
