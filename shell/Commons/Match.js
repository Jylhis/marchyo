// Pure fuzzy-match scoring and highlighting for the launcher views (apps,
// emoji, clipboard).
//
// Dual citizenship like Format.js: QML imports this directly and ignores the
// CommonJS guard, while Node loads it in tests/shell/launcher-test.js. Stay
// pure — no Qt types, no globals, no I/O — and never add a `.pragma`
// directive (Node cannot parse one; pinned by contracts-test.sh).
//
// match(text, query): null when the query characters do not appear in order,
// otherwise { score, positions } where `positions` are the matched character
// indices in `text` (for highlighting) and a higher score is better. Tiers,
// high to low:
//   2000-range: query is a prefix of text (shorter text wins ties)
//   1400-range: query is a contiguous run at a word boundary inside text
//   1000-range: query is a contiguous run mid-word
//    200-550:   query chars appear in order but scattered — adjacency and
//               word-boundary bonuses minus a skipped-character penalty set
//               the spread (a tighter, boundary-aligned match ranks higher)
//      0:       empty query (caller sorts by name)
//
// score(text, query) is the number-only wrapper the emoji and clipboard
// filters use: match's score, or -1 for no match.

function isBoundary(ch) {
    return ch === " " || ch === "-" || ch === "_" || ch === "(" || ch === "/" || ch === ".";
}

function range(start, len) {
    var out = [];
    for (var i = 0; i < len; i++)
        out.push(start + i);
    return out;
}

function match(text, query) {
    var t = String(text == null ? "" : text).toLowerCase();
    var q = String(query == null ? "" : query).toLowerCase();
    if (q.length === 0)
        return {
            score: 0,
            positions: []
        };
    if (t.length === 0)
        return null;

    var at = t.indexOf(q);
    if (at >= 0) {
        var contiguous = range(at, q.length);
        if (at === 0)
            return {
                score: 2000 - Math.min(t.length, 999),
                positions: contiguous
            };
        if (isBoundary(t.charAt(at - 1)))
            return {
                score: 1400 - Math.min(at, 399),
                positions: contiguous
            };
        return {
            score: 1000 - Math.min(at, 399),
            positions: contiguous
        };
    }

    // Scattered subsequence: greedy left-to-right, rewarding a character that
    // falls directly after the previous match (a run) or on a word boundary,
    // and penalising the characters skipped to reach each one. A missing
    // character means no match at all.
    var ti = 0;
    var bonus = 0;
    var run = 0;
    var positions = [];
    for (var qi = 0; qi < q.length; qi++) {
        var idx = t.indexOf(q.charAt(qi), ti);
        if (idx === -1)
            return null;
        if (positions.length > 0 && idx === positions[positions.length - 1] + 1) {
            run += 1;
            bonus += 10 + run * 5;
        } else {
            run = 0;
        }
        if (idx === 0 || isBoundary(t.charAt(idx - 1)))
            bonus += 15;
        bonus -= idx - ti;
        positions.push(idx);
        ti = idx + 1;
    }
    return {
        score: 200 + Math.max(0, Math.min(350, bonus)),
        positions: positions
    };
}

function score(text, query) {
    var m = match(text, query);
    return m ? m.score : -1;
}

function escapeHtml(s) {
    return String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Build a Text.StyledText string with the matched characters wrapped in a
// coloured span. `color` is an "#rrggbb" string supplied by the caller (QML
// passes Color.accent.toString()); every character is HTML-escaped first so a
// name containing "&" or "<" can never break the markup.
function highlight(text, positions, color) {
    var s = String(text == null ? "" : text);
    var mark = {};
    var list = positions || [];
    for (var i = 0; i < list.length; i++)
        mark[list[i]] = true;
    var out = "";
    for (var c = 0; c < s.length; c++) {
        var ch = escapeHtml(s.charAt(c));
        out += mark[c] ? '<font color="' + color + '">' + ch + "</font>" : ch;
    }
    return out;
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        match: match,
        score: score,
        highlight: highlight,
        escapeHtml: escapeHtml
    };
