// Unit tests for shell/Commons/MenuModel.js: the menu tree, the per-key
// overlay, routes, guards, search, provider parsers and the cheat sheet rows.
//
// Run: node tests/shell/menu-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const M = require(path.join(__dirname, "..", "..", "shell", "Commons", "MenuModel.js"));
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

// A tiny substring matcher standing in for fuzzysort.
const match = (text, q) => {
  const i = String(text).toLowerCase().indexOf(q.toLowerCase());
  return i < 0 ? null : { score: 1000 - i, positions: [i] };
};

const raw = {
  capture: { label: "Capture", order: 10 },
  "capture.screenshot": { label: "Screenshot", action: "exec", target: "marchyo capture screenshot", aliases: ["screen shot"], order: 1 },
  "capture.record": { label: "Record", action: "exec", target: "marchyo capture record", description: "Screen recording", order: 2 },
  system: { label: "System", order: 20 },
  "system.hibernate": { label: "Hibernate", action: "exec", target: "marchyo hibernate", when: "test -e /etc/marchyo/hibernation" },
  "system.lock": { label: "Lock", action: "exec", target: "marchyo lock", order: 1 },
  appearance: { label: "Appearance", order: 5 },
  "appearance.theme": { label: "Theme", action: "provider", provider: "themes" },
  nolabel: { action: "exec" },
  "orphan.child": { label: "Orphan", action: "exec", target: "true" }
};
const model = M.build(raw);

test("the tree sorts by order then label and drops entries without a label or parent", () => {
  assert.deepEqual(model.children[""], ["appearance", "capture", "system"]);
  assert.deepEqual(model.children["capture"], ["capture.screenshot", "capture.record"]);
  assert.equal(model.entries.nolabel, undefined);
  assert.equal((model.children["orphan"] || []).length, 0);
});

test("the overlay merges per key and per field, and null removes", () => {
  const merged = M.mergeOverlay(raw, {
    "capture.screenshot": { label: "Shot" },
    "capture.custom": { label: "Custom", action: "exec", target: "true" },
    "capture.record": null
  });
  assert.equal(merged["capture.screenshot"].label, "Shot");
  assert.equal(merged["capture.screenshot"].target, "marchyo capture screenshot");
  assert.equal(merged["capture.custom"].label, "Custom");
  assert.equal(merged["capture.record"], undefined);
  assert.equal(raw["capture.record"].label, "Record", "the base is not mutated");
  assert.deepEqual(Object.keys(M.mergeOverlay(raw, "junk")).length, Object.keys(raw).length);
});

test("routes resolve to the deepest menu", () => {
  assert.equal(M.resolveRoute(model, ""), "");
  assert.equal(M.resolveRoute(model, "capture"), "capture");
  assert.equal(M.resolveRoute(model, "capture.screenshot"), "capture");
  assert.equal(M.resolveRoute(model, "appearance.theme"), "appearance.theme");
  assert.equal(M.resolveRoute(model, "nope.deeper"), "");
  assert.deepEqual(M.breadcrumb(model, "appearance.theme").map((b) => b.label), ["Appearance", "Theme"]);
});

test("guarded entries stay hidden until their guard passed", () => {
  const ids = M.descendants(model, "system");
  const guards = M.guardsFor(model, ids);
  assert.deepEqual(guards.map((g) => g.id), ["system.hibernate"]);
  assert.deepEqual(M.levelRows(model, "system", null).map((r) => r.id), ["system.lock"]);
  const state = M.parseGuardOutput(guards, "0\n");
  assert.deepEqual(M.levelRows(model, "system", state).map((r) => r.id), ["system.lock", "system.hibernate"]);
  assert.deepEqual(M.levelRows(model, "system", M.parseGuardOutput(guards, "")).map((r) => r.id), ["system.lock"]);
});

test("the guard script passes each command as an argument", () => {
  const argv = M.guardArgv([{ cmd: "test -e /x; rm -rf ~" }, { cmd: "true" }]);
  assert.deepEqual(argv.slice(0, 2), ["sh", "-c"]);
  assert.equal(argv[argv.length - 2], "test -e /x; rm -rf ~");
  assert.ok(!argv[2].includes("rm -rf"), "commands never enter the script text");
});

test("checked guards mark rows", () => {
  const m = M.build({ a: { label: "A", action: "exec", target: "x", checked: "true" } });
  const guards = M.guardsFor(m, ["a"]);
  assert.equal(M.levelRows(m, "", M.parseGuardOutput(guards, "0"))[0].checked, true);
  assert.equal(M.levelRows(m, "", M.parseGuardOutput(guards, ""))[0].checked, false);
});

test("search covers label, aliases and description, below the route", () => {
  const all = M.searchRows(model, "", "shot", null, match).map((r) => r.id);
  assert.deepEqual(all, ["capture.screenshot"]);
  assert.deepEqual(M.searchRows(model, "", "screen shot", null, match).map((r) => r.id), ["capture.screenshot"]);
  assert.deepEqual(M.searchRows(model, "", "recording", null, match).map((r) => r.id), ["capture.record"]);
  assert.deepEqual(M.searchRows(model, "system", "shot", null, match), []);
  const row = M.searchRows(model, "", "lock", null, match)[0];
  assert.equal(row.subtitle, "System");
});

test("provider entries are searchable and plain submenus are not", () => {
  const ids = M.searchRows(model, "", "the", null, match).map((r) => r.id);
  assert.ok(ids.includes("appearance.theme"));
  assert.ok(!ids.includes("capture"));
});

test("provider parsers read the CLI outputs", () => {
  const S = M.PROVIDER_SPECS;
  assert.deepEqual(S.themes.parse('{"themes":[{"name":"a","variant":"dark","current":true}]}'), [
    { title: "a", subtitle: "dark", checked: true, argv: ["theme", "set", "a"] }
  ]);
  assert.deepEqual(S.fonts.parse('{"fonts":["Mono","Other"]}').map((f) => f.argv), [["font", "set", "Mono"], ["font", "set", "Other"]]);
  assert.deepEqual(S.languages.parse('{"languages":[{"code":"fi","name":"Suomi","englishName":"Finnish","current":false}]}'), [
    { title: "Finnish", subtitle: "Suomi", checked: false, argv: ["language", "fi"] }
  ]);
  const ppd = "* performance:\n    CpuDriver:\tamd_pstate\n    Degraded:   no\n\n  balanced:\n    CpuDriver:\tx\n\n  power-saver:\n    CpuDriver:\tx\n";
  assert.deepEqual(S["power-profiles"].parse(ppd).map((p) => [p.title, p.checked]), [["performance", true], ["balanced", false], ["power-saver", false]]);
  assert.deepEqual(S.wallpapers.parse("/a/b.png\n\n/c/d.jpg\n")[1].argv, ["bg", "set", "/c/d.jpg"]);
  for (const k of Object.keys(S).filter((n) => n !== "wallpapers" && n !== "power-profiles")) assert.deepEqual(S[k].parse("not json"), [], k);
});

test("chords fall into modifier planes", () => {
  assert.equal(M.planeOf("SUPER + A"), "Super");
  assert.equal(M.planeOf("SUPER + SHIFT + A"), "Super+Shift");
  assert.equal(M.planeOf("SUPER + CTRL + A"), "Super+Ctrl");
  assert.equal(M.planeOf("SUPER + CTRL + ALT + A"), "Super+Ctrl+Alt");
  assert.equal(M.planeOf("SUPER + SHIFT + CTRL + A"), "Super+Ctrl");
  assert.equal(M.planeOf("Print"), "Other");
  assert.equal(M.planeOf("CTRL + Print"), "Other");
});

test("the cheat sheet groups by plane and searches description and chord", () => {
  const rows = M.sheetRows([
    { combo: "SUPER + CTRL + A", description: "Audio panel", group: "Panels", dispatch: "hl.dsp.global(\"marchyo:panel.audio\")" },
    { combo: "SUPER + A", description: "Alpha", group: "Apps" },
    { combo: "Print", description: "Screenshot", group: "Capture" },
    { description: "broken" }
  ]);
  assert.deepEqual(rows.map((r) => r.title), ["Alpha", "Audio panel", "Screenshot"]);
  assert.equal(rows[1].dispatch, "hl.dsp.global(\"marchyo:panel.audio\")");
  assert.equal(rows[0].dispatch, "");
  assert.deepEqual(M.searchSheet(rows, "audio", match).map((r) => r.title), ["Audio panel"]);
  assert.deepEqual(M.searchSheet(rows, "ctrl a", match).map((r) => r.title), ["Audio panel"]);
  assert.equal(M.searchSheet(rows, "", match).length, 3);
});

console.log("# " + passed + " passed");
