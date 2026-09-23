#!/usr/bin/env node
// Headless unit tests for the launcher's pure JS modules
// (Commons/Match.js, Commons/EmojiData.js, Commons/Cliphist.js).
// Same shape as format-test.js: plain asserts, process exit code is the gate.
"use strict";

const assert = require("assert");
const Match = require("../../shell/Commons/Match.js");

// Empty query matches everything with the baseline score.
assert.strictEqual(Match.score("Firefox", ""), 0);
// Prefix beats word-start beats scattered subsequence.
const prefix = Match.score("Firefox Web Browser", "fire");
const word = Match.score("GNU Image Manipulation Program", "image");
const scattered = Match.score("GNU Image Manipulation Program", "gimp");
assert.ok(prefix > word, `prefix ${prefix} should beat word-start ${word}`);
assert.ok(word > scattered, `word-start ${word} should beat scattered ${scattered}`);
assert.ok(scattered >= 0, "subsequence match should not be -1");
// Misses return -1.
assert.strictEqual(Match.score("Settings", "zzz"), -1);
assert.strictEqual(Match.score("", "a"), -1);
// Case-insensitive both ways.
assert.ok(Match.score("Nautilus", "nau") > 0);
assert.ok(Match.score("nautilus", "NAU") > 0);

console.log("launcher-test: Match.js ok");
