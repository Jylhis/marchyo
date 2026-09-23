// Pure fuzzy-match scoring for the launcher views (apps, emoji, clipboard).
//
// Dual citizenship like Format.js: QML imports this directly and ignores the
// CommonJS guard, while Node loads it in tests/shell/launcher-test.js. Stay
// pure — no Qt types, no globals, no I/O — and never add a `.pragma`
// directive (Node cannot parse one; pinned by contracts-test.sh).
//
// score(text, query): -1 = no match, otherwise >= 0. Higher is better.
//   1000-range: query is a prefix of text (shorter text wins ties)
//    800-range: query starts at a word boundary inside text
//    100-range: query chars appear in order (scattered subsequence)
//      0:       empty query (caller sorts by name)

function isBoundary(ch) {
    return ch === " " || ch === "-" || ch === "_" || ch === "(" || ch === "/" || ch === ".";
}

function score(text, query) {
    var t = String(text == null ? "" : text).toLowerCase();
    var q = String(query == null ? "" : query).toLowerCase();
    if (q.length === 0)
        return 0;
    if (t.length === 0)
        return -1;
    var at = t.indexOf(q);
    if (at === 0)
        return 1000 - Math.min(t.length, 999);
    if (at > 0 && isBoundary(t.charAt(at - 1)))
        return 800 - Math.min(at, 799);
    var ti = 0;
    var cost = 0;
    for (var qi = 0; qi < q.length; qi++) {
        ti = t.indexOf(q.charAt(qi), ti);
        if (ti === -1)
            return -1;
        cost += ti;
        ti += 1;
    }
    return Math.max(0, 100 - Math.min(cost, 99));
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        score: score
    };
