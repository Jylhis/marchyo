// Unit tests for shell/Commons/Overview.js: the window overview's grouping,
// search filter, keyboard navigation and tile layout math.
//
// Run: node tests/shell/overview-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const Overview = require(path.join(__dirname, "..", "..", "shell", "Commons", "Overview.js"));
const Match = require(path.join(__dirname, "..", "..", "shell", "Commons", "Match.js"));

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

const client = (over) =>
  Object.assign(
    {
      address: "0xa",
      mapped: true,
      hidden: false,
      at: [0, 0],
      size: [100, 100],
      workspace: { id: 1, name: "1" },
      floating: false,
      monitor: 0,
      class: "kitty",
      title: "shell",
      focusHistoryID: 0,
    },
    over,
  );

const win = (over) => Overview.normalizeWindow(client(over));

// ── normalizeWindow ─────────────────────────────────────────────────────────

test("normalizeWindow maps a hyprctl client record", () => {
  assert.deepEqual(win({ address: "0x5f", at: [10, 20], size: [300, 200], focusHistoryID: 2 }), {
    address: "0x5f",
    title: "shell",
    cls: "kitty",
    workspaceId: 1,
    workspaceName: "1",
    monitorId: 0,
    x: 10,
    y: 20,
    w: 300,
    h: 200,
    floating: false,
    focusHistory: 2,
  });
});

test("normalizeWindow adds the 0x prefix Quickshell's address lacks", () => {
  assert.equal(win({ address: "5f3a" }).address, "0x5f3a");
});

test("normalizeWindow drops unmapped, hidden, special-workspace and address-less windows", () => {
  assert.equal(win({ mapped: false }), null);
  assert.equal(win({ hidden: true }), null);
  assert.equal(win({ workspace: { id: -98, name: "special:magic" } }), null);
  assert.equal(win({ address: "" }), null);
  assert.equal(Overview.normalizeWindow(null), null);
  assert.equal(Overview.normalizeWindow("x"), null);
});

test("normalizeWindow tolerates missing geometry and title", () => {
  const w = Overview.normalizeWindow({ address: "0x1", workspace: { id: 2 } });
  assert.equal(w.title, "");
  assert.equal(w.cls, "");
  assert.equal(w.workspaceName, "2");
  assert.deepEqual([w.x, w.y, w.w, w.h], [0, 0, 0, 0]);
});

test("normalizeWindow reads array-like geometry (a lastIpcObject sequence)", () => {
  const seq = (a, b) => ({ 0: a, 1: b, length: 2 });
  const w = win({ at: seq(5, 6), size: seq(70, 80) });
  assert.deepEqual([w.x, w.y, w.w, w.h], [5, 6, 70, 80]);
});

// ── monitorRect ─────────────────────────────────────────────────────────────

test("monitorRect divides by scale and swaps axes on a rotated output", () => {
  assert.deepEqual(Overview.monitorRect({ id: 1, name: "DP-1", x: 1920, y: 0, width: 3840, height: 2160, scale: 2 }), {
    id: 1,
    name: "DP-1",
    x: 1920,
    y: 0,
    w: 1920,
    h: 1080,
  });
  const r = Overview.monitorRect({ id: 0, width: 1920, height: 1080, scale: 1, transform: 1 });
  assert.deepEqual([r.w, r.h], [1080, 1920]);
  assert.equal(Overview.monitorRect({ width: 100, height: 50, scale: 0 }).w, 100);
  assert.equal(Overview.monitorRect(null), null);
});

// ── groupByWorkspace ────────────────────────────────────────────────────────

test("groupByWorkspace sorts workspaces by id and windows in reading order", () => {
  const ws = [
    { id: 3, name: "3", monitorId: 0 },
    { id: 1, name: "1", monitorId: 0 },
  ];
  const wins = [
    win({ address: "0xc", at: [500, 0] }),
    win({ address: "0xf", at: [0, 0], floating: true }),
    win({ address: "0xb", at: [0, 0] }),
    win({ address: "0xd", at: [0, 400] }),
    win({ address: "0xe", workspace: { id: 3, name: "3" } }),
  ];
  const groups = Overview.groupByWorkspace(wins, ws);
  assert.deepEqual(
    groups.map((g) => g.id),
    [1, 3],
  );
  assert.deepEqual(
    groups[0].windows.map((w) => w.address),
    ["0xb", "0xc", "0xd", "0xf"],
  );
  assert.deepEqual(
    groups[1].windows.map((w) => w.address),
    ["0xe"],
  );
});

test("groupByWorkspace keeps empty workspaces and adds unlisted ones", () => {
  const groups = Overview.groupByWorkspace([win({ workspace: { id: 7, name: "seven" }, monitor: 1 })], [
    { id: 2, name: "2", monitorId: 0 },
    { id: -99, name: "special:x", monitorId: 0 },
  ]);
  assert.deepEqual(
    groups.map((g) => [g.id, g.name, g.monitorId, g.windows.length]),
    [
      [2, "2", 0, 0],
      [7, "seven", 1, 1],
    ],
  );
  assert.deepEqual(Overview.groupByWorkspace(null, null), []);
});

// ── filterWindows ───────────────────────────────────────────────────────────

const score = (text, q) => Match.score(text, q);

test("filterWindows matches every window on an empty query", () => {
  const wins = [win({ address: "0x1" }), win({ address: "0x2" })];
  assert.deepEqual(Overview.filterWindows(wins, "  ", score), { "0x1": 0, "0x2": 0 });
});

test("filterWindows matches on title or class through the fuzzy scorer", () => {
  const wins = [
    win({ address: "0x1", class: "firefox", title: "Mozilla Firefox" }),
    win({ address: "0x2", class: "kitty", title: "nvim README.md" }),
    win({ address: "0x3", class: "org.gnome.Nautilus", title: "Files" }),
  ];
  assert.deepEqual(Object.keys(Overview.filterWindows(wins, "fire", score)), ["0x1"]);
  assert.deepEqual(Object.keys(Overview.filterWindows(wins, "kitty", score)), ["0x2"]);
  assert.deepEqual(Object.keys(Overview.filterWindows(wins, "readme", score)), ["0x2"]);
  assert.deepEqual(Object.keys(Overview.filterWindows(wins, "zzzz", score)), []);
  assert.ok(Overview.filterWindows(wins, "fire", score)["0x1"] > 0);
});

// ── navigation ──────────────────────────────────────────────────────────────

const navGroups = () =>
  Overview.groupByWorkspace(
    [
      win({ address: "0x1", workspace: { id: 1 }, at: [0, 0], focusHistoryID: 3 }),
      win({ address: "0x2", workspace: { id: 1 }, at: [900, 0], focusHistoryID: 0 }),
      win({ address: "0x3", workspace: { id: 2 }, focusHistoryID: 1 }),
      win({ address: "0x4", workspace: { id: 4 }, focusHistoryID: 2 }),
    ],
    [{ id: 3, name: "3", monitorId: 0 }],
  );
const all = { "0x1": 0, "0x2": 0, "0x3": 0, "0x4": 0 };

test("navOrder lists matching windows in display order", () => {
  assert.deepEqual(Overview.navOrder(navGroups(), all), ["0x1", "0x2", "0x3", "0x4"]);
  assert.deepEqual(Overview.navOrder(navGroups(), { "0x4": 5, "0x2": 1 }), ["0x2", "0x4"]);
  assert.deepEqual(Overview.navOrder(navGroups(), null), []);
});

test("bestMatch picks the most recent window for an empty query, else the top score", () => {
  assert.equal(Overview.bestMatch(navGroups(), all, ""), "0x2");
  assert.equal(Overview.bestMatch(navGroups(), { "0x1": 10, "0x3": 50, "0x4": 50 }, "x"), "0x3");
  assert.equal(Overview.bestMatch(navGroups(), {}, "x"), "");
});

test("step wraps both ways and recovers from an unknown current", () => {
  const order = ["0x1", "0x2", "0x3"];
  assert.equal(Overview.step(order, "0x1", 1), "0x2");
  assert.equal(Overview.step(order, "0x3", 1), "0x1");
  assert.equal(Overview.step(order, "0x1", -1), "0x3");
  assert.equal(Overview.step(order, "gone", 1), "0x1");
  assert.equal(Overview.step(order, "", -1), "0x3");
  assert.equal(Overview.step([], "0x1", 1), "");
});

test("stepRow jumps a grid row, skipping workspaces without matches", () => {
  // Workspaces in order: 1 (0x1, 0x2), 2 (0x3), 3 (empty), 4 (0x4); 2 columns.
  const g = navGroups();
  assert.equal(Overview.stepRow(g, all, "0x2", 1, 2), "0x2"); // ws1 -> ws3 (empty), then past the end
  assert.equal(Overview.stepRow(g, all, "0x3", 1, 2), "0x4"); // ws2 (idx 1) -> ws4 (idx 3)
  assert.equal(Overview.stepRow(g, all, "0x4", -1, 2), "0x3");
  assert.equal(Overview.stepRow(g, all, "0x1", -1, 2), "0x1"); // top row stays
  assert.equal(Overview.stepRow(g, { "0x1": 0, "0x3": 0 }, "0x3", 1, 2), "0x3");
  assert.equal(Overview.stepRow(g, all, "gone", 1, 2), "0x1");
});

// ── layout math ─────────────────────────────────────────────────────────────

test("gridColumns grows roughly with the square root, capped", () => {
  assert.deepEqual(
    [0, 1, 2, 4, 5, 10, 30].map((n) => Overview.gridColumns(n, 5)),
    [1, 1, 2, 3, 3, 4, 5],
  );
  assert.equal(Overview.gridColumns(4, 1), 1);
});

test("tileSize fits the aspect into the tighter axis", () => {
  // Width-bound: 2 cols of (1000 - 20) / 2 = 490 wide; height allows 1000.
  assert.deepEqual(Overview.tileSize(1000, 1000, 2, 1, 20, 2), { w: 490, h: 245 });
  // Height-bound: 1 row of 100 high at 16:9 -> 177 wide.
  assert.deepEqual(Overview.tileSize(5000, 100, 2, 1, 0, 16 / 9), { w: 177, h: 100 });
  assert.deepEqual(Overview.tileSize(0, 0, 3, 3, 10, 1), { w: 0, h: 0 });
});

test("windowRect scales into the tile relative to the monitor and clamps", () => {
  const mon = { x: 1920, y: 0, w: 1920, h: 1080 };
  assert.deepEqual(Overview.windowRect({ x: 1920, y: 0, w: 960, h: 1080 }, mon, 192, 108), {
    x: 0,
    y: 0,
    w: 96,
    h: 108,
  });
  const r = Overview.windowRect({ x: 3700, y: 1000, w: 500, h: 500 }, mon, 192, 108);
  assert.equal(r.x, 178);
  assert.equal(r.y, 100);
  assert.ok(r.x + r.w <= 192 && r.y + r.h <= 108);
  // No monitor: positions from the origin at scale 1.
  assert.deepEqual(Overview.windowRect({ x: 5, y: 5, w: 10, h: 10 }, null, 100, 100), { x: 5, y: 5, w: 10, h: 10 });
});

// ── module surface ──────────────────────────────────────────────────────────

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(Overview).sort(), [
    "bestMatch",
    "filterWindows",
    "gridColumns",
    "groupByWorkspace",
    "monitorRect",
    "navOrder",
    "normalizeWindow",
    "step",
    "stepRow",
    "tileSize",
    "windowRect",
  ]);
});

console.log("# " + passed + " passed");
