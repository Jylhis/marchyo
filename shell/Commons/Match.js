// Fuzzy-match scoring and highlighting for the launcher providers (apps,
// emoji, clipboard, theme, windows, power).
//
// Dual citizenship like Format.js: Commons/Fuzzy.qml imports this from QML
// and ignores the CommonJS guard, while Node loads it in
// tests/shell/launcher-test.js. Stay
// pure (no Qt types, no I/O) and never add a `.pragma` directive (Node cannot
// parse one; pinned by contracts-test.sh).
//
// Ranking is the vendored fuzzysort (Commons/fuzzysort.js), passed in as
// `engine`. QML code calls this through the Commons/Fuzzy singleton, which
// imports both files and binds the engine (a `.import` directive here would
// be a syntax error to Node); under Node an omitted engine is `require`d.
// Targets are prepared per call rather than through fuzzysort's
// prepared-target cache, so an open launcher never grows a cache of every
// clipboard row and emoji name it has scored; a caller that scores the same
// text on every keystroke (the emoji catalog) keeps its own `prepare(text)`
// result and passes that in place of the text.
//
// match(text, query, engine): `text` is a string or a prepare() result.
// null when the query does not match, otherwise { score, positions } where
// `positions` are the matched character indices in the text (for
// highlighting) and a higher score is better. fuzzysort's 0..1 score maps
// onto 1..2000, so a match always outranks the empty-query baseline of 0 and
// the per-field penalties in Launcher/AppsProvider.qml keep their scale. A
// space in the query matches each word separately, in any order. Empty
// query: { score: 0, positions: [] } (caller sorts by name).
//
// score(text, query, engine) is the number-only wrapper the filters use:
// match's score, or -1 for no match.

function resolveEngine(engine) {
    if (engine)
        return engine;
    if (typeof require === "function")
        return require("./fuzzysort.js");
    throw new Error("Match.js: no fuzzysort engine (QML goes through Commons/Fuzzy)");
}

function prepare(text, engine) {
    return resolveEngine(engine).prepare(String(text == null ? "" : text));
}

function match(text, query, engine) {
    var prepared = text !== null && typeof text === "object" ? text : null;
    var t = prepared ? String(prepared.target) : String(text == null ? "" : text);
    var q = String(query == null ? "" : query).trim();
    if (q.length === 0)
        return {
            score: 0,
            positions: []
        };
    if (t.length === 0)
        return null;
    var fz = resolveEngine(engine);
    var r = fz.single(q, prepared || fz.prepare(t));
    if (!r)
        return null;
    return {
        score: 1 + Math.round(Math.max(0, Math.min(1, r.score)) * 1999),
        positions: r.indexes
    };
}

function score(text, query, engine) {
    var m = match(text, query, engine);
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
        prepare: prepare,
        match: match,
        score: score,
        highlight: highlight,
        escapeHtml: escapeHtml
    };
