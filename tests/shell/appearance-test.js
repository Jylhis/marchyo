#!/usr/bin/env node
// Headless unit tests for shell/Commons/Appearance.js: the runtime style file,
// the wallpaper list, the thumbnail script output and the picker navigation.
// Same shape as launcher-test.js: plain asserts, process exit code is the gate.
"use strict";

const assert = require("assert");
const A = require("../../shell/Commons/Appearance.js");

// style.json: every key optional, bad values read as the declarative default.
assert.deepStrictEqual(A.parseStyle(""), { reduceMotion: false, uiFont: "", barPosition: "", barBackground: "" });
assert.deepStrictEqual(A.parseStyle("not json"), { reduceMotion: false, uiFont: "", barPosition: "", barBackground: "" });
assert.deepStrictEqual(A.parseStyle("[1]"), { reduceMotion: false, uiFont: "", barPosition: "", barBackground: "" });
assert.deepStrictEqual(
    A.parseStyle('{"reduceMotion":true,"uiFont":" Inter ","barPosition":"bottom","barBackground":"glassy"}'),
    { reduceMotion: true, uiFont: "Inter", barPosition: "bottom", barBackground: "glassy" });
assert.deepStrictEqual(
    A.parseStyle('{"reduceMotion":"yes","uiFont":7,"barPosition":"left","barBackground":"solid"}'),
    { reduceMotion: false, uiFont: "", barPosition: "", barBackground: "" });
assert.deepStrictEqual(A.parseStyle('{"barPosition":"top"}').barPosition, "top");

// Bar opacity per mode.
assert.strictEqual(A.barAlpha("", 0.85), 0.85);
assert.strictEqual(A.barAlpha("opaque", 0.85), 1);
assert.strictEqual(A.barAlpha("clear", 0.85), 0);
assert.strictEqual(A.barAlpha("glassy", 0.85), 0.6);
assert.strictEqual(A.barAlpha("glassy", 0.4), 0.4);

// bg list: bare array or { backgrounds }, junk dropped, defaults filled.
const bgs = A.parseBackgrounds(JSON.stringify([
    { path: "/w/a.png", name: "Alpha", source: "theme", current: true },
    { path: "/w/b.jpg", source: "bogus" },
    { name: "no path" },
    null
]));
assert.deepStrictEqual(bgs, [
    { path: "/w/a.png", name: "Alpha", source: "theme", current: true },
    { path: "/w/b.jpg", name: "b.jpg", source: "user", current: false }
]);
assert.deepStrictEqual(A.parseBackgrounds('{"backgrounds":[{"path":"/w/c.png"}]}').map(b => b.name), ["c.png"]);
assert.deepStrictEqual(A.parseBackgrounds("not json"), []);
assert.deepStrictEqual(A.parseBackgrounds("{}"), []);

// thumbnail script lines.
assert.deepStrictEqual(A.parseThumbLine("/w/a.png\t/c/x.png"), { path: "/w/a.png", thumb: "/c/x.png" });
assert.strictEqual(A.parseThumbLine("no tab"), null);
assert.strictEqual(A.parseThumbLine("\t/c/x.png"), null);
assert.strictEqual(A.parseThumbLine("/w/a.png\t"), null);
assert.strictEqual(A.parseThumbLine(""), null);

// grid navigation: 3 columns, 8 cells (rows of 3, 3, 2).
assert.strictEqual(A.step(0, "right", 3, 8), 1);
assert.strictEqual(A.step(7, "right", 3, 8), 7);
assert.strictEqual(A.step(0, "left", 3, 8), 0);
assert.strictEqual(A.step(4, "up", 3, 8), 1);
assert.strictEqual(A.step(1, "up", 3, 8), 1);
assert.strictEqual(A.step(1, "down", 3, 8), 4);
assert.strictEqual(A.step(5, "down", 3, 8), 7, "down into a short last row lands on its last cell");
assert.strictEqual(A.step(7, "down", 3, 8), 7);
assert.strictEqual(A.step(4, "home", 3, 8), 0);
assert.strictEqual(A.step(4, "end", 3, 8), 7);
assert.strictEqual(A.step(-1, "right", 3, 8), 1);
assert.strictEqual(A.step(2, "down", 3, 3), 2);
assert.strictEqual(A.step(0, "down", 3, 0), -1);

// preselect the current row.
assert.strictEqual(A.currentIndex([{ current: false }, { current: true }]), 1);
assert.strictEqual(A.currentIndex([{ current: false }]), 0);
assert.strictEqual(A.currentIndex([]), -1);

assert.strictEqual(A.barTextRole(1), "text");
assert.strictEqual(A.barTextRole(0.85), "text");
assert.strictEqual(A.barTextRole(0.6), "textHeading");
assert.strictEqual(A.barTextRole(0), "textHeading");

assert.strictEqual(A.nextBarBackground(""), "opaque");
assert.strictEqual(A.nextBarBackground("opaque"), "glassy");
assert.strictEqual(A.nextBarBackground("glassy"), "clear");
assert.strictEqual(A.nextBarBackground("clear"), "opaque");

console.log("appearance-test: ok");
