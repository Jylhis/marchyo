#!/usr/bin/env node
// Headless unit tests for the launcher's pure JS modules
// (Commons/Match.js over the vendored Commons/fuzzysort.js,
// Commons/LauncherProviders.js, Commons/EmojiData.js, Commons/Cliphist.js).
// Same shape as format-test.js: plain asserts, process exit code is the gate.
"use strict";

const assert = require("assert");
const Match = require("../../shell/Commons/Match.js");
const EmojiData = require("../../shell/Commons/EmojiData.js");
const Cliphist = require("../../shell/Commons/Cliphist.js");
const Providers = require("../../shell/Commons/LauncherProviders.js");
const fuzzysort = require("../../shell/Commons/fuzzysort.js");
const fs = require("fs");
const path = require("path");

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

// match() reports the matched character indices for highlighting.
assert.deepStrictEqual(Match.match("Firefox", "fire").positions, [0, 1, 2, 3]);
assert.strictEqual(Match.match("Settings", "zzz"), null);
assert.strictEqual(Match.match("Firefox", "").score, 0);
// A word-boundary hit is highlighted at its offset, not from zero.
assert.deepStrictEqual(Match.match("GNU Image", "image").positions, [4, 5, 6, 7, 8]);
// Adjacent scattered characters beat gappy ones for the same query.
assert.ok(Match.score("cdxe", "cde") > Match.score("cxdxe", "cde"),
    "an adjacent subsequence should outscore a gappier one");

// highlight() wraps matched chars and HTML-escapes the rest.
assert.strictEqual(Match.highlight("A&B", [0], "#ff0000"),
    '<font color="#ff0000">A</font>&amp;B');
assert.strictEqual(Match.highlight("ab", [], "#fff"), "ab");

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
// parseLine: id TAB payload; non-image binary payloads are skipped.
const line = Cliphist.parseLine("42\tHello, wor=6Cd!");
assert.ok(line && line.raw === "42\tHello, wor=6Cd!" && line.text === "Hello, world!");
assert.strictEqual(line.id, "42");
assert.strictEqual(line.image, null);
assert.strictEqual(Cliphist.parseLine("7\t[[ binary data 1.png ]]"), null);
assert.strictEqual(Cliphist.parseLine("garbage-without-a-tab"), null);

// Image entries: cliphist's preview string parses to size/format/dimensions.
assert.deepStrictEqual(Cliphist.parseImage("[[ binary data 12 KiB png 800x600 ]]"),
    { bytes: 12288, sizeText: "12 KiB", format: "png", width: 800, height: 600 });
assert.deepStrictEqual(Cliphist.parseImage("[[ binary data 1.5 MiB jpeg 4032x3024 ]]"),
    { bytes: 1572864, sizeText: "1.5 MiB", format: "jpeg", width: 4032, height: 3024 });
assert.strictEqual(Cliphist.parseImage("[[ binary data 900 B gif 1x1 ]]").bytes, 900);
// Non-image binaries, unknown formats and near-misses are not images.
assert.strictEqual(Cliphist.parseImage("[[ binary data 3 KiB application/pdf ]]"), null);
assert.strictEqual(Cliphist.parseImage("[[ binary data 3 KiB tiff 10x10 ]]"), null);
assert.strictEqual(Cliphist.parseImage("[[ binary data 12 KiB png 800x600 ]] trailing"), null);
assert.strictEqual(Cliphist.parseImage("[[ binary data 12 KiB png ]]"), null);
assert.strictEqual(Cliphist.parseImage("plain text"), null);
assert.strictEqual(Cliphist.parseImage(null), null);
const img = Cliphist.parseLine("5650\t[[ binary data 140 KiB png 902x397 ]]");
assert.ok(img && img.id === "5650" && img.text === "" && img.image.format === "png");
assert.deepStrictEqual([img.image.width, img.image.height], [902, 397]);
// Only a numeric id ever reaches `cliphist decode`.
assert.strictEqual(Cliphist.parseLine("-1 x\t[[ binary data 1 KiB png 1x1 ]]"), null);
assert.strictEqual(Cliphist.parseLine("\t[[ binary data 1 KiB png 1x1 ]]"), null);
// Cache names are id-keyed and change with the image, so a reused id misses.
assert.strictEqual(Cliphist.cacheName("5650", img.image), "5650-902x397-143360.png");
assert.notStrictEqual(Cliphist.cacheName("5650", Cliphist.parseImage("[[ binary data 2 KiB png 10x10 ]]")),
    Cliphist.cacheName("5650", img.image));
assert.ok(/^[0-9]+-[0-9]+x[0-9]+-[0-9]+\.[a-z0-9]+$/.test(Cliphist.cacheName("1", img.image)));
assert.strictEqual(Cliphist.describeImage(img.image), "png 902x397 \u00b7 140 KiB");

// Vendored fuzzysort: the pinned release, loadable as CommonJS.
const fuzzysortSrc = fs.readFileSync(path.join(__dirname, "../../shell/Commons/fuzzysort.js"), "utf8");
assert.ok(/^\/\/ fuzzysort 3\.1\.0, vendored/.test(fuzzysortSrc), "fuzzysort.js lost its pinned-version header");
assert.ok(fuzzysortSrc.includes("MIT License") && fuzzysortSrc.includes("Copyright (c) 2018 Stephen Kamenar"),
    "fuzzysort.js lost its license header");
assert.ok(!fuzzysortSrc.includes("\r"), "fuzzysort.js must use LF line endings");
for (const fn of ["single", "go", "prepare", "cleanup"])
    assert.strictEqual(typeof fuzzysort[fn], "function", "fuzzysort." + fn + " missing");
assert.deepStrictEqual(fuzzysort.single("fire", "Firefox").indexes, [0, 1, 2, 3]);

// Commons/Fuzzy passes the engine explicitly; Node's default is the same file.
assert.deepStrictEqual(Match.match("Firefox", "fire", fuzzysort), Match.match("Firefox", "fire"));
assert.strictEqual(Match.score("Settings", "zzz", fuzzysort), -1);
// A prepare() result scores exactly like its text.
const prepared = Match.prepare("GNU Image Manipulation Program");
assert.deepStrictEqual(Match.match(prepared, "gimp"), Match.match("GNU Image Manipulation Program", "gimp"));
assert.strictEqual(Match.score(prepared, "zzz"), -1);
assert.strictEqual(Match.score(prepared, ""), 0);

// Match ranks through fuzzysort: matches land in 1..2000, above the empty
// baseline; a multi-word query matches words in any order.
for (const [t, q] of [["Firefox", "fire"], ["Firefox", "Firefox"], ["cxdxe", "cde"]]) {
    const s = Match.score(t, q);
    assert.ok(s >= 1 && s <= 2000, `score ${s} for ${q} in ${t} out of range`);
}
assert.strictEqual(Match.score("Firefox", "Firefox"), 2000, "an exact match scores the ceiling");
assert.ok(Match.score("Visual Studio Code", "code studio") > 0, "words match in any order");
assert.strictEqual(Match.score("Firefox", "   "), 0, "a blank query is the empty baseline");
assert.ok(Match.score("Calf\u00e9", "cafe") > 0);

// Ranking: a shorter exact-prefix title beats a longer one.
assert.ok(Match.score("Files", "fi") > Match.score("Firefox Web Browser", "fi"));

// Prefix routing: only apps mode routes; the rest of the text is the query.
assert.deepStrictEqual(Providers.route("apps", "fire"), { provider: "apps", query: "fire" });
assert.deepStrictEqual(Providers.route("apps", ""), { provider: "apps", query: "" });
assert.deepStrictEqual(Providers.route("apps", "=2+2"), { provider: "calc", query: "2+2" });
assert.deepStrictEqual(Providers.route("apps", "= 10 usd to eur"), { provider: "calc", query: "10 usd to eur" });
assert.deepStrictEqual(Providers.route("apps", ">theme"), { provider: "theme", query: "" });
assert.deepStrictEqual(Providers.route("apps", ">theme light"), { provider: "theme", query: "light" });
assert.deepStrictEqual(Providers.route("apps", "#term"), { provider: "windows", query: "term" });
assert.deepStrictEqual(Providers.route("apps", "!reb"), { provider: "power", query: "reb" });
// An unknown ">" command stays an app search.
assert.deepStrictEqual(Providers.route("apps", ">foo"), { provider: "apps", query: ">foo" });
// A prefix only counts at the start.
assert.deepStrictEqual(Providers.route("apps", "a=b"), { provider: "apps", query: "a=b" });
// emoji and clipboard modes search the whole text, prefixes included.
assert.deepStrictEqual(Providers.route("emoji", "=smile"), { provider: "emoji", query: "=smile" });
assert.deepStrictEqual(Providers.route("clipboard", "#tag"), { provider: "clipboard", query: "#tag" });
// Closed or unknown mode routes nowhere.
assert.deepStrictEqual(Providers.route("", "=1"), { provider: "", query: "" });
assert.deepStrictEqual(Providers.route("bogus", "x"), { provider: "", query: "" });
// Every prefix is unique and resolvable.
assert.strictEqual(Providers.prefixFor("calc"), "=");
assert.strictEqual(Providers.prefixFor("theme"), ">theme");
assert.strictEqual(Providers.prefixFor("windows"), "#");
assert.strictEqual(Providers.prefixFor("power"), "!");
assert.strictEqual(Providers.prefixFor("apps"), "");
assert.strictEqual(new Set(Providers.PREFIXES.map(p => p.prefix)).size, Providers.PREFIXES.length);

// rank(): empty query keeps input order; a query keeps matches only, best
// first, title hits above subtitle hits, and preserves extra fields.
const activated = [];
const rows = ["Lock", "Log out", "Reboot", "Shut down"].map((title, i) => ({
    title, subtitle: i === 2 ? "restart the machine" : "", activate: () => activated.push(title)
}));
assert.deepStrictEqual(Providers.rank(rows, "", Match.match).map(r => r.title), ["Lock", "Log out", "Reboot", "Shut down"]);
const lo = Providers.rank(rows, "lo", Match.match);
assert.deepStrictEqual(lo.map(r => r.title).slice(0, 2).sort(), ["Lock", "Log out"]);
assert.ok(!lo.some(r => r.title === "Reboot"), "non-matching rows are dropped");
assert.deepStrictEqual(Providers.rank(rows, "shut", Match.match)[0].positions, [0, 1, 2, 3]);
const restart = Providers.rank(rows, "restart", Match.match);
assert.deepStrictEqual(restart.map(r => r.title), ["Reboot"], "subtitle hits count");
assert.deepStrictEqual(restart[0].positions, [], "a subtitle hit highlights nothing in the title");
const titleVsSub = Providers.rank([
    { title: "Alpha", subtitle: "light" },
    { title: "light", subtitle: "" }
], "light", Match.match);
assert.strictEqual(titleVsSub[0].title, "light", "a title hit outranks the same subtitle hit");
restart[0].activate();
assert.deepStrictEqual(activated, ["Reboot"], "rank keeps activate()");
assert.strictEqual(Providers.rank(null, "x", Match.match).length, 0);

// Power actions are the marchyo CLI power verbs.
assert.deepStrictEqual(Providers.POWER_ACTIONS.map(a => a.verb),
    ["lock", "logout", "suspend", "hibernate", "reboot", "shutdown"]);

// `marchyo theme list --format json`.
assert.deepStrictEqual(Providers.parseThemes('{"themes":[{"name":"jylhis-dark","variant":"dark","current":false},' +
    '{"name":"jylhis-light","variant":"light","current":true},{"variant":"x"}]}'), [
    { name: "jylhis-dark", variant: "dark", current: false },
    { name: "jylhis-light", variant: "light", current: true }
]);
assert.deepStrictEqual(Providers.parseThemes("not json"), []);
assert.deepStrictEqual(Providers.parseThemes('{"themes":7}'), []);

// `hyprctl clients -j`: hidden/unmapped dropped, most recently focused first,
// empty titles fall back to the class.
const clients = Providers.parseClients(JSON.stringify([
    { address: "0xa", title: "Docs", class: "firefox", workspace: { id: 2, name: "2" }, mapped: true, hidden: false, focusHistoryID: 2 },
    { address: "0xb", title: "", class: "com.mitchellh.ghostty", workspace: { id: 1, name: "1" }, mapped: true, hidden: false, focusHistoryID: 0 },
    { address: "0xc", title: "Hidden", class: "x", workspace: { id: 1, name: "1" }, mapped: true, hidden: true, focusHistoryID: 1 },
    { address: "0xd", title: "Unmapped", class: "y", workspace: { id: 1, name: "1" }, mapped: false, hidden: false, focusHistoryID: 3 },
    { title: "No address" }
]));
assert.deepStrictEqual(clients.map(c => c.address), ["0xb", "0xa"]);
assert.strictEqual(clients[0].title, "com.mitchellh.ghostty");
assert.strictEqual(clients[1].workspace, "2");
assert.deepStrictEqual(Providers.parseClients("{}"), []);
assert.deepStrictEqual(Providers.parseClients(""), []);

// `qalc -t` output: the last non-empty line, trimmed.
assert.strictEqual(Providers.parseCalc("4\n"), "4");
assert.strictEqual(Providers.parseCalc("warning\n\u20ac8.62\n\n"), "\u20ac8.62");
assert.strictEqual(Providers.parseCalc(""), "");

console.log("launcher-test: all ok");
