#!/usr/bin/env node
// Headless unit tests for the launcher's pure JS modules
// (Commons/Match.js, Commons/EmojiData.js, Commons/Cliphist.js).
// Same shape as format-test.js: plain asserts, process exit code is the gate.
"use strict";

const assert = require("assert");
const Match = require("../../shell/Commons/Match.js");
const EmojiData = require("../../shell/Commons/EmojiData.js");
const Cliphist = require("../../shell/Commons/Cliphist.js");

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

// EmojiData.parse: dev subset is well-formed and grouped.
const emoji = EmojiData.parse(EmojiData.RAW);
assert.ok(emoji.length >= 8, "dev emoji subset too small");
for (const e of emoji) {
    assert.ok(e.group && e.subgroup && e.chars && e.name, "incomplete entry: " + JSON.stringify(e));
    assert.ok(!e.name.includes("|"), "name must not contain the field separator");
}
const grin = emoji.find(e => e.name === "grinning face");
assert.ok(grin && grin.chars === "\u{1F600}");

// Cliphist payload decoding: quoted-printable bytes -> UTF-8 string.
assert.strictEqual(Cliphist.decodePayload("plain text"), "plain text");
assert.strictEqual(Cliphist.decodePayload("calf=C3=A9"), "calf\u00e9");
// U+1F600 = F0 9F 98 80 as a 4-byte UTF-8 sequence -> surrogate pair.
assert.strictEqual(Cliphist.decodePayload("=F0=9F=98=80"), "\u{1F600}");
assert.strictEqual(Cliphist.decodePayload("100=25 ok"), "100% ok");
// parseLine: id TAB payload; binary payloads are skipped.
const line = Cliphist.parseLine("42\tHello, wor=6Cd!");
assert.ok(line && line.raw === "42\tHello, wor=6Cd!" && line.text === "Hello, world!");
assert.strictEqual(Cliphist.parseLine("7\t[[ binary data 1.png ]]"), null);
assert.strictEqual(Cliphist.parseLine("garbage-without-a-tab"), null);

console.log("launcher-test: all ok");
