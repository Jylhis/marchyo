// Unit tests for shell/Commons/PluginManifest.js: dev index validation, the
// public manifest and the summon scope rules.
//
// Run: node tests/shell/plugin-manifest-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const PM = require(path.join(__dirname, "..", "..", "shell", "Commons", "PluginManifest.js"));

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

const DIR = "/state/marchyo/shell/dev-plugins";
const index = (...plugins) => JSON.stringify({ plugins });
const good = (over) =>
  Object.assign(
    {
      id: "acme.weather",
      name: "Weather",
      kinds: ["panel"],
      entryPoints: { panel: "Panel.qml" }
    },
    over
  );

test("a valid panel entry gets a file URL under its own directory", () => {
  const r = PM.devEntries(index(good()), DIR, []);
  assert.equal(r.refused.length, 0);
  assert.equal(r.entries[0].entryPoints.panel, "file://" + DIR + "/acme.weather/Panel.qml");
  assert.equal(r.entries[0].dev, true);
});

test("the index cannot choose the directory", () => {
  const r = PM.devEntries(index(good({ dir: "/etc" })), DIR, []);
  assert.ok(r.entries[0].entryPoints.panel.startsWith("file://" + DIR + "/acme.weather/"));
});

test("a dev entry never mounts at shell start, whatever keepLoaded says", () => {
  const r = PM.devEntries(index(good({ keepLoaded: true })), DIR, []);
  assert.equal(r.entries[0].keepLoaded, false);
});

test("kinds that run at startup are refused", () => {
  for (const kind of ["service", "daemon", "bar"]) {
    const r = PM.devEntries(index(good({ kinds: [kind], entryPoints: { [kind]: "A.qml" } })), DIR, []);
    assert.equal(r.entries.length, 0, kind);
    assert.match(r.refused[0].reason, /needs a rebuild/);
  }
});

test("reserved namespaces and baked ids are refused", () => {
  const r = PM.devEntries(
    index(good({ id: "marchyo.x" }), good({ id: "omarchy.x" }), good({ id: "baked.one" })),
    DIR,
    ["baked.one"]
  );
  assert.equal(r.entries.length, 0);
  assert.deepEqual(r.refused.map((x) => x.reason), ["reserved namespace", "reserved namespace", "id already taken"]);
});

test("path traversal and absolute entry points are refused", () => {
  for (const ep of ["../x.qml", "/etc/x.qml", "a/../../x.qml", "file:///x.qml", ""]) {
    const r = PM.devEntries(index(good({ entryPoints: { panel: ep } })), DIR, []);
    assert.equal(r.entries.length, 0, ep);
  }
  for (const id of ["a/b", "..", "a b", ""]) {
    assert.equal(PM.devEntries(index(good({ id })), DIR, []).entries.length, 0, id);
  }
});

test("an entry needs the key of every declared kind", () => {
  const r = PM.devEntries(index(good({ kinds: ["panel", "menu"] })), DIR, []);
  assert.equal(r.entries.length, 0);
});

test("an unreadable index yields nothing", () => {
  assert.deepEqual(PM.devEntries("{nope", DIR, []), { entries: [], refused: [] });
  assert.deepEqual(PM.devEntries("", DIR, []), { entries: [], refused: [] });
});

test("the second entry with a repeated id is refused", () => {
  const r = PM.devEntries(index(good(), good()), DIR, []);
  assert.equal(r.entries.length, 1);
  assert.equal(r.refused[0].reason, "id already taken");
});

test("a dev entry carries its replaces list, non-strings dropped", () => {
  const r = PM.devEntries(index(good({ replaces: ["panel.audio", 7, null] })), DIR, []);
  assert.deepEqual(r.entries[0].replaces, ["panel.audio"]);
  assert.deepEqual(PM.devEntries(index(good()), DIR, []).entries[0].replaces, []);
  assert.deepEqual(PM.devEntries(index(good({ replaces: "panel.audio" })), DIR, []).entries[0].replaces, []);
});

test("replacementFor names the claiming plugin or an empty string", () => {
  const entries = [
    { id: "a.audio", kinds: ["panel"], replaces: ["panel.audio", "panel.power"] },
    { id: "a.plain", kinds: ["panel"] },
    { id: "a.pk", kinds: ["daemon"], replaces: ["polkit"] }
  ];
  assert.equal(PM.replacementFor(entries, "panel.audio"), "a.audio");
  assert.equal(PM.replacementFor(entries, "panel.power"), "a.audio");
  assert.equal(PM.replacementFor(entries, "polkit"), "a.pk");
  assert.equal(PM.replacementFor(entries, "panel.network"), "");
  assert.equal(PM.replacementFor([], "polkit"), "");
});

test("panelReplacers lists the plugins that replace a panel, minus the kept one", () => {
  const entries = [
    { id: "a.audio", kinds: ["bar-widget"], replaces: ["panel.audio"] },
    { id: "a.net", kinds: ["bar-widget"], replaces: ["panel.network", "polkit"] },
    { id: "a.pk", kinds: ["service"], replaces: ["polkit"] },
    { id: "a.plain", kinds: ["panel"] }
  ];
  assert.deepEqual(PM.panelReplacers(entries, ""), ["a.audio", "a.net"]);
  assert.deepEqual(PM.panelReplacers(entries, "a.net"), ["a.audio"]);
  assert.deepEqual(PM.panelReplacers([], ""), []);
});

test("pickWidget prefers the widget on the requested output", () => {
  const a = { screen: "DP-1" };
  const b = { screen: "HDMI-A-1" };
  const nameOf = (w) => w.screen;
  assert.equal(PM.pickWidget([a, b], "HDMI-A-1", nameOf), b);
  assert.equal(PM.pickWidget([a, b], "eDP-1", nameOf), a);
  assert.equal(PM.pickWidget([a, b], "", nameOf), a);
  assert.equal(PM.pickWidget(undefined, "DP-1", nameOf), null);
});

test("kind helpers", () => {
  assert.equal(PM.isHosted({ kinds: ["bar-widget", "menu"] }), true);
  assert.equal(PM.isBarWidgetOnly({ kinds: ["bar-widget", "menu"] }), false);
  assert.equal(PM.isBarWidgetOnly({ kinds: ["bar-widget"] }), true);
  assert.equal(PM.isHosted({ kinds: ["service"] }), false);
});

test("the public manifest carries no entry points or paths", () => {
  const m = PM.publicManifest(PM.devEntries(index(good()), DIR, []).entries[0]);
  assert.equal(m.id, "acme.weather");
  assert.equal(m.entryPoints, undefined);
  assert.ok(!JSON.stringify(m).includes(DIR));
});

test("a plugin controls itself, a bar plugin controls UI plugins", () => {
  const panel = { id: "a.panel", kinds: ["panel"] };
  const other = { id: "a.other", kinds: ["panel"] };
  const bar = { id: "a.bar", kinds: ["bar"] };
  const svc = { id: "a.svc", kinds: ["service"] };
  assert.equal(PM.mayControl(panel, panel), true);
  assert.equal(PM.mayControl(panel, other), false);
  assert.equal(PM.mayControl(bar, other), true);
  assert.equal(PM.mayControl(bar, svc), false);
  assert.equal(PM.mayControl(null, panel), false);
});

test("firstPartyServiceFor reaches the own service, and omarchy services from a bar", () => {
  const media = { id: "omarchy.media", kinds: ["service", "bar-widget"] };
  const pk = { id: "omarchy.polkit", kinds: ["service"], replaces: ["polkit"] };
  const bar = { id: "acme.bar", kinds: ["bar"] };
  const widget = { id: "acme.widget", kinds: ["bar-widget"] };
  assert.equal(PM.mayUseFirstPartyService(media, media), true);
  assert.equal(PM.mayUseFirstPartyService(bar, media), true);
  assert.equal(PM.mayUseFirstPartyService(bar, pk), false);
  assert.equal(PM.mayUseFirstPartyService(widget, media), false);
  assert.equal(PM.mayUseFirstPartyService(media, null), false);
});

console.log("# " + passed + " passed");
