// Unit tests for shell/Commons/Displays.js: the display panel's pure logic.
//
// Run: node tests/shell/displays-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const D = require(path.join(__dirname, "..", "..", "shell", "Commons", "Displays.js"));

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

const MODES_4K = [
  "3840x2160@60.00Hz",
  "3840x2160@59.94Hz",
  "3840x2160@144.00Hz",
  "2560x1440@144.00Hz",
  "2560x1440@60.00Hz",
  "1920x1080@60.00Hz",
  "1280x720@60.00Hz",
  "1600x1200@60.00Hz",
  "1024x768@60.00Hz",
];

test("resolutionOptions lists native first-class sizes of one aspect, smallest first", () => {
  assert.deepEqual(D.resolutionOptions(MODES_4K, 3840, 2160), ["1920x1080", "2560x1440", "3840x2160"]);
});

test("resolutionOptions keeps the current odd size and tolerates bad input", () => {
  assert.ok(D.resolutionOptions(MODES_4K, 1600, 1200).includes("1600x1200"));
  assert.deepEqual(D.resolutionOptions(null, 1, 1), []);
  assert.deepEqual(D.resolutionOptions(["junk"], 1, 1), []);
});

test("resolutionLabel uses the names people know", () => {
  assert.equal(D.resolutionLabel("3840x2160"), "4K");
  assert.equal(D.resolutionLabel("2560x1440"), "1440p");
  assert.equal(D.resolutionLabel("5120x2880"), "5K");
  assert.equal(D.resolutionLabel("weird"), "weird");
});

test("refreshOptions folds 59.94 into 60 and hides a single slow choice", () => {
  assert.deepEqual(D.refreshOptions(MODES_4K, 3840, 2160), [
    { label: "60", rate: "60" },
    { label: "144", rate: "144" },
  ]);
  assert.deepEqual(D.refreshOptions(MODES_4K, 1920, 1080), []);
});

test("modeFor picks the fastest mode of a size, or the exact rate", () => {
  assert.equal(D.modeFor(MODES_4K, "3840x2160"), "3840x2160@144");
  assert.equal(D.modeFor(MODES_4K, "3840x2160", "60"), "3840x2160@60");
  assert.equal(D.modeFor(MODES_4K, "800x600"), "");
});

test("cleanScale rounds up to a scale the mode divides by", () => {
  assert.equal(D.cleanScale(1.5, 3840, 2160), "1.5");
  assert.equal(D.cleanScale(1.25, 1920, 1080), "1.25");
  assert.equal(D.cleanScale(1.3, 1920, 1080), "1.33");
  assert.equal(D.cleanScale(2, 1920, 1080), "2");
  assert.equal(D.cleanScale(0, 1920, 1080), "");
  assert.equal(D.cleanScale("x", 1920, 1080), "");
});

test("cleanScale never returns a scale that leaves fractional logical pixels", () => {
  for (const [w, h] of [[1920, 1080], [2560, 1440], [3840, 2160], [2256, 1504], [1366, 768]]) {
    for (const s of D.SCALE_PRESETS) {
      const clean = Number(D.cleanScale(s, w, h));
      assert.ok(clean > 0, w + "x" + h + " @" + s);
      const units = clean * 120;
      const near = [Math.floor(units), Math.ceil(units)];
      assert.ok(near.some((u) => u > 0 && (w * 120) % u === 0 && (h * 120) % u === 0), w + "x" + h + " @" + s + " -> " + clean);
    }
  }
});

test("availableScales snaps presets and drops duplicates", () => {
  assert.deepEqual(D.availableScales(1920, 1080, [1, 1.25, 1.5, 2]), [1, 1.25, 1.5, 2]);
  const snapped = D.availableScales(1920, 1080, [1.3, 1.31, 1.32]);
  assert.equal(snapped.length, 1);
});

test("rotation: transforms, degrees and the right-click cycle", () => {
  assert.equal(D.transformFor(90), 1);
  assert.equal(D.transformFor(270), 3);
  assert.equal(D.transformFor(45), -1);
  assert.equal(D.degreesOf(3), 270);
  assert.equal(D.degreesOf(5), -1);
  assert.equal(D.nextRotation(0), 1);
  assert.equal(D.nextRotation(3), 0);
  assert.equal(D.nextRotation(6), 0);
  assert.deepEqual(D.turnedSize(1920, 1080, 0, 1), { w: 1080, h: 1920 });
  assert.deepEqual(D.turnedSize(1920, 1080, 0, 2), { w: 1920, h: 1080 });
  assert.deepEqual(D.turnedSize(1080, 1920, 1, 3), { w: 1080, h: 1920 });
});

const RAW = JSON.stringify([
  { id: 0, name: "eDP-1", description: "BOE 0x095F", make: "BOE", model: "0x095F", width: 2256, height: 1504, refreshRate: 60, scale: 1.5, x: 0, y: 0, transform: 0, mirrorOf: "none", disabled: false, focused: true, availableModes: ["2256x1504@60.00Hz"] },
  { id: 1, name: "DP-3", description: "Dell U2720Q ABC", make: "Dell", model: "U2720Q", width: 3840, height: 2160, refreshRate: 60, scale: 2, x: 1504, y: 0, transform: 0, mirrorOf: "none", disabled: false, availableModes: MODES_4K },
  { id: 2, name: "bad name;", description: "x", width: 1, height: 1 },
]);

test("parseDisplays names mirrors, skips unsafe connectors and tolerates junk", () => {
  const list = D.parseDisplays(RAW);
  assert.deepEqual(list.map((d) => d.name), ["eDP-1", "DP-3"]);
  assert.equal(list[0].internal, true);
  assert.equal(list[1].identity, "Dell U2720Q ABC");
  assert.deepEqual(D.parseDisplays("not json"), []);
  assert.deepEqual(D.parseDisplays(null), []);
  const mirrored = D.parseDisplays(JSON.stringify([
    { id: 0, name: "eDP-1", mirrorOf: "none" },
    { id: 1, name: "HDMI-A-1", mirrorOf: 0 },
  ]));
  assert.equal(mirrored[1].mirrorOf, "eDP-1");
  assert.equal(D.isMirrored(mirrored), true);
});

test("displayTitle names the built-in panel and skips hex model codes", () => {
  const list = D.parseDisplays(RAW);
  assert.equal(D.displayTitle(list[0], "Built-in"), "Built-in");
  assert.equal(D.displayTitle(list[1]), "U2720Q");
  assert.equal(D.displayTitle({ name: "DP-1", model: "0x1234", make: "ACME" }), "ACME");
});

test("canMirror needs the built-in panel and an external", () => {
  const list = D.parseDisplays(RAW);
  assert.equal(D.canMirror(list), true);
  assert.equal(D.canMirror([list[0]]), false);
  assert.equal(D.canMirror([list[1]]), false);
});

const R = (name, x, y, w, h) => ({ name, x, y, w, h });

test("logicalRect divides by scale and swaps for a quarter turn", () => {
  const d = D.parseDisplays(RAW)[1];
  assert.deepEqual(D.logicalRect(d), R("DP-3", 1504, 0, 1920, 1080));
  assert.deepEqual(D.logicalRect({ ...d, transform: 1 }), R("DP-3", 1504, 0, 1080, 1920));
  assert.deepEqual(D.logicalRect({ ...d, transform: 2 }), R("DP-3", 1504, 0, 1920, 1080));
});

test("dropDisplay lands against a side, overlap-free, normalised", () => {
  const rects = [R("a", 0, 0, 1000, 800), R("b", 1000, 0, 1000, 800)];
  const out = D.dropDisplay(rects, "b", 20, 50, 40);
  const b = out.find((r) => r.name === "b");
  assert.ok(!D.anyOverlap(out));
  assert.ok(b.x === 1000 || b.y === 800 || b.y + b.h === 0 || b.x + b.w === 0 || b.x === 0);
  assert.equal(Math.min(...out.map((r) => r.x)), 0);
  assert.equal(Math.min(...out.map((r) => r.y)), 0);
  assert.equal(D.dropDisplay([R("a", 0, 0, 10, 10)], "a", 5, 5, 10), null);
});

test("dropDisplay snaps edges within the snap distance", () => {
  const rects = [R("a", 0, 0, 1000, 800), R("b", 1000, 0, 500, 400)];
  const out = D.dropDisplay(rects, "b", 1010, 12, 40);
  assert.deepEqual(out.find((r) => r.name === "b"), R("b", 1000, 0, 500, 400));
});

test("dropDisplay never overlaps, whatever the drop point", () => {
  const rects = [R("a", 0, 0, 1920, 1080), R("b", 1920, 0, 1280, 800), R("c", 0, 1080, 1280, 720)];
  for (let x = -2000; x <= 4000; x += 500) {
    for (let y = -1500; y <= 3000; y += 500) {
      const out = D.dropDisplay(rects, "c", x, y, 40);
      assert.ok(out && !D.anyOverlap(out), "drop at " + x + "," + y);
    }
  }
});

test("resizeLayout shifts neighbours to the right and below by the growth", () => {
  const rects = [R("a", 0, 0, 1000, 800), R("b", 1000, 0, 1000, 800), R("c", 0, 800, 1000, 600)];
  const out = D.resizeLayout(rects, "a", 1500, 1000);
  const by = Object.fromEntries(out.rects.map((r) => [r.name, r]));
  assert.equal(by.b.x, 1500);
  assert.equal(by.c.y, 1000);
  assert.ok(!D.anyOverlap(out.rects));
});

test("resizeLayout shrinks without leaving the neighbour behind", () => {
  const rects = [R("a", 0, 0, 2000, 1000), R("b", 2000, 0, 1000, 800)];
  const out = D.resizeLayout(rects, "a", 1000, 500);
  assert.equal(out.rects.find((r) => r.name === "b").x, 1000);
});

test("resizeLayout steps never overlap: away first, then the resized one, then closers", () => {
  const rects = [R("a", 0, 0, 1000, 800), R("b", 1000, 0, 1000, 800)];
  const grow = D.resizeLayout(rects, "a", 1600, 800);
  assert.deepEqual(grow.order, ["b", "a"]);
  const shrink = D.resizeLayout(rects, "a", 600, 800);
  assert.deepEqual(shrink.order, ["a", "b"]);
  for (const plan of [grow, shrink]) {
    let state = D.copyRects(rects);
    for (const name of plan.order) {
      const target = plan.rects.find((r) => r.name === name);
      state = state.map((r) => (r.name === name ? { ...target } : r));
      assert.ok(!D.anyOverlap(state), "overlap after moving " + name);
    }
  }
});

test("resizeLayout falls back to a gap when sideways and down shifts collide", () => {
  const rects = [R("a", 0, 0, 1000, 1000), R("b", 1000, 0, 1000, 1000), R("c", 0, 1000, 1000, 1000)];
  const out = D.resizeLayout(rects, "a", 1400, 1400);
  assert.ok(!D.anyOverlap(out.rects));
});

test("monitorCall and buildEval write Lua tables and refuse unsafe fields", () => {
  assert.equal(
    D.monitorCall({ output: "DP-1", mode: "3840x2160@60", position: "0x0", scale: 1.5, transform: 1 }),
    'hl.monitor({ output = "DP-1", mode = "3840x2160@60", position = "0x0", scale = 1.5, transform = 1 })',
  );
  assert.equal(D.monitorCall({ output: "DP-1", disabled: true }), 'hl.monitor({ output = "DP-1", disabled = true })');
  assert.equal(D.monitorCall({ output: "DP-1", mirror: "eDP-1" }), 'hl.monitor({ output = "DP-1", mirror = "eDP-1" })');
  assert.equal(D.monitorCall({ output: 'DP-1"})os.exit() --' }), "");
  assert.equal(D.monitorCall({ output: "DP-1", mode: '1x1"})' }), "");
  assert.equal(D.monitorCall({ output: "DP-1", position: "a" }), "");
  assert.equal(D.monitorCall({ output: "DP-1", scale: -1 }), "");
  assert.equal(D.monitorCall({ output: "DP-1", transform: 9 }), "");
  assert.equal(D.buildEval([{ output: "A", position: "0x0" }, { output: "B", position: "1x0" }]), 'hl.monitor({ output = "A", position = "0x0" }) hl.monitor({ output = "B", position = "1x0" })');
  assert.equal(D.buildEval([{ output: "A" }, { output: "bad name" }]), "");
});

test("planChange resizes one display and shifts the neighbour in the same plan", () => {
  const list = D.parseDisplays(RAW);
  // DP-3 from 4K at scale 2 (1920x1080 logical) to 1440p at scale 2 (1280x720).
  const plan = D.planChange(list, "DP-3", { mode: "2560x1440@144" });
  const dp = plan.entries.find((e) => e.output === "DP-3");
  assert.equal(dp.mode, "2560x1440@144");
  assert.equal(dp.scale, 2);
  assert.equal(dp.position, "1504x0");
  assert.equal(plan.saves["DP-3"].mode, "2560x1440@144");
  assert.match(D.buildEval(plan.entries), /output = "DP-3", mode = "2560x1440@144"/);
});

test("planChange snaps the scale to a clean one for the new mode", () => {
  const list = D.parseDisplays(RAW);
  list[1].scale = 1.25;
  const plan = D.planChange(list, "DP-3", { mode: "1920x1080@60" });
  const scale = plan.entries.find((e) => e.output === "DP-3").scale;
  assert.equal((1920 * 120) % Math.round(scale * 120), 0);
  assert.equal((1080 * 120) % Math.round(scale * 120), 0);
});

test("planChange rotates: a quarter turn swaps the footprint and moves neighbours", () => {
  const list = D.parseDisplays(RAW);
  const plan = D.planChange(list, "eDP-1", { transform: 1 });
  const edp = plan.entries.find((e) => e.output === "eDP-1");
  assert.equal(edp.transform, 1);
  // 2256x1504 at 1.5 is 1504x1003; turned it is 1003x1504, so DP-3 moves left.
  const dp = plan.entries.find((e) => e.output === "DP-3");
  assert.equal(dp.position, "1003x0");
  assert.equal(plan.saves["eDP-1"].transform, 1);
  const turnedBack = D.planChange(list, "eDP-1", { transform: 2 });
  assert.equal(turnedBack.entries.find((e) => e.output === "DP-3").position, "1504x0");
});

test("planChange leaves a lone display to Hyprland's placement", () => {
  const lone = D.parseDisplays(RAW).slice(0, 1);
  const plan = D.planChange(lone, "eDP-1", { scale: 2 });
  assert.equal(plan.entries.length, 1);
  assert.equal(plan.entries[0].position, "auto");
  assert.equal(plan.entries[0].scale, 2);
});

test("settings round-trip through the tab-separated file", () => {
  let s = {};
  s = D.updateSetting(s, "Dell U2720Q ABC", { mode: "3840x2160@60", position: "0x0", scale: 1.5, transform: 1 });
  s = D.updateSetting(s, "BOE 0x095F", { enabled: false });
  s = D.updateSetting(s, "Dell U2720Q ABC", { mirror: "internal" });
  const text = D.serializeSettings(s);
  assert.equal(text, "0\t\t\t\t\t\tBOE 0x095F\n\t3840x2160@60\t0x0\t1.5\t1\tinternal\tDell U2720Q ABC\n");
  assert.deepEqual(D.parseSettings(text), s);
});

test("parseSettings skips malformed lines and updateSetting never mutates", () => {
  assert.deepEqual(D.parseSettings("junk\n\t\t\t\t\t\t\n1\t2\n"), {});
  const base = { id: { enabled: "1", mode: "", position: "", scale: "", transform: "", mirror: "" } };
  const next = D.updateSetting(base, "id", { scale: 2 });
  assert.equal(base.id.scale, "");
  assert.equal(next.id.scale, "2");
});

test("tabs and newlines in an identity cannot break the file", () => {
  const s = D.updateSetting({}, "bad\tid\nline", { scale: 1 });
  assert.equal(D.serializeSettings(s).split("\n").length, 2);
});

test("applySaves keys the rows by identity", () => {
  const list = D.parseDisplays(RAW);
  const s = D.applySaves({}, list, { "DP-3": { scale: 2 }, "missing": { scale: 3 } });
  assert.deepEqual(Object.keys(s), ["Dell U2720Q ABC"]);
});

test("parseDdcDetect maps DRM connectors to i2c buses", () => {
  const text = [
    "Display 1",
    "   I2C bus:  /dev/i2c-5",
    "   DRM_connector:           card1-DP-3",
    "   Monitor:                 DEL:DELL U2720Q:ABC",
    "",
    "Invalid display",
    "   I2C bus:  /dev/i2c-7",
    "   DRM_connector:           card1-HDMI-A-1",
    "",
    "Display 2",
    "   I2C bus:  /dev/i2c-9",
    "   DRM_connector:           card1-DP-4",
  ].join("\n");
  assert.deepEqual(D.parseDdcDetect(text), { "DP-3": 5, "DP-4": 9 });
  assert.deepEqual(D.parseDdcDetect(""), {});
});

test("parseVcp and backlightPercent give a clamped percent or -1", () => {
  assert.equal(D.parseVcp("VCP 10 C 50 100\n"), 50);
  assert.equal(D.parseVcp("VCP 10 C 255 255"), 100);
  assert.equal(D.parseVcp("VCP 10 C 0 100"), 1);
  assert.equal(D.parseVcp("garbage"), -1);
  assert.equal(D.backlightPercent("intel_backlight,backlight,4800,50%,9600\n"), 50);
  assert.equal(D.backlightPercent("intel_backlight,backlight,0,0%,9600"), 1);
  assert.equal(D.backlightPercent("nonsense"), -1);
});

test("the keyboard nudge step is a positive whole number of logical pixels", () => {
  assert.ok(Number.isInteger(D.NUDGE_STEP) && D.NUDGE_STEP > 0);
});

console.log(passed + " tests passed");
