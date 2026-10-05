// Pure launcher palette logic: prefix routing, provider output parsers, and
// the shared ranking the list providers use.
//
// Dual citizenship like Format.js: Services/Launcher.qml and the Launcher/
// providers import this from QML, tests/shell/launcher-test.js loads it from
// Node. Pure functions only (no Qt types, no I/O) and no `.pragma` line (Node
// cannot parse one). Fuzzy matching is passed in as a function (QML passes
// Commons/Fuzzy's match, Node tests Match.match) rather than imported, since
// a `.import` directive is a syntax error to Node.

// Prefixes that route the apps palette to another provider. Checked in order,
// first hit wins; the rest of the text (leading whitespace dropped) becomes
// that provider's query.
var PREFIXES = [
    {
        prefix: ">theme",
        provider: "theme"
    },
    {
        prefix: "=",
        provider: "calc"
    },
    {
        prefix: "#",
        provider: "windows"
    },
    {
        prefix: "!",
        provider: "power"
    }
];

// Launcher modes the IPC opens directly. Only "apps" routes on prefixes; the
// emoji and clipboard modes search their own data with the whole text.
var MODES = ["apps", "emoji", "clipboard"];

function prefixFor(provider) {
    for (var i = 0; i < PREFIXES.length; i++)
        if (PREFIXES[i].provider === provider)
            return PREFIXES[i].prefix;
    return "";
}

// (mode, query text) -> { provider, query }. provider is "" when the launcher
// is closed or the mode is unknown.
function route(mode, text) {
    var t = String(text == null ? "" : text);
    if (MODES.indexOf(mode) < 0)
        return {
            provider: "",
            query: ""
        };
    if (mode === "apps") {
        for (var i = 0; i < PREFIXES.length; i++) {
            var p = PREFIXES[i];
            if (t.indexOf(p.prefix) === 0)
                return {
                    provider: p.provider,
                    query: t.slice(p.prefix.length).replace(/^\s+/, "")
                };
        }
    }
    return {
        provider: mode,
        query: t
    };
}

// The session verbs the "!" provider offers. `verb` is the marchyo CLI
// subcommand; "lock" goes through the shell's own lock instead (see
// Launcher/PowerProvider.qml).
var POWER_ACTIONS = [
    {
        verb: "lock",
        title: "Lock",
        icon: "system-lock-screen"
    },
    {
        verb: "logout",
        title: "Log out",
        icon: "system-log-out"
    },
    {
        verb: "suspend",
        title: "Suspend",
        icon: "system-suspend"
    },
    {
        verb: "hibernate",
        title: "Hibernate",
        icon: "system-suspend-hibernate"
    },
    {
        verb: "reboot",
        title: "Reboot",
        icon: "system-reboot"
    },
    {
        verb: "shutdown",
        title: "Shut down",
        icon: "system-shutdown"
    }
];

// A subtitle hit ranks below a title hit of the same quality.
var SUBTITLE_PENALTY = 300;

// Rank result rows ({ title, subtitle, ... }) against `query` with
// `matchFn(text, query) -> { score, positions } | null` (Match.match). Empty
// query: every row in input order, positions cleared. Otherwise only matching
// rows, best first; ties keep input order. Rows are shallow-copied with
// `score` and `positions` set, so their other fields (activate()) survive.
function rank(rows, query, matchFn) {
    var q = String(query == null ? "" : query).trim();
    var list = rows || [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var row = list[i];
        if (q.length === 0) {
            out.push(withScore(row, 0, [], i));
            continue;
        }
        var byTitle = matchFn(row.title, q);
        var bySub = row.subtitle ? matchFn(row.subtitle, q) : null;
        var best = byTitle ? byTitle.score : -1;
        var positions = byTitle ? byTitle.positions : [];
        if (bySub && bySub.score - SUBTITLE_PENALTY > best) {
            best = bySub.score - SUBTITLE_PENALTY;
            positions = [];
        }
        if (byTitle || bySub)
            out.push(withScore(row, best, positions, i));
    }
    out.sort(function (a, b) {
        return (b.score - a.score) || (a.order - b.order);
    });
    return out;
}

function withScore(row, score, positions, order) {
    var copy = {};
    for (var k in row)
        copy[k] = row[k];
    copy.score = score;
    copy.positions = positions;
    copy.order = order;
    return copy;
}

// `marchyo theme list --format json` -> [{ name, variant, current }].
// Malformed output yields [].
function parseThemes(text) {
    var parsed;
    try {
        parsed = JSON.parse(String(text == null ? "" : text));
    } catch (e) {
        return [];
    }
    var themes = parsed && Array.isArray(parsed.themes) ? parsed.themes : [];
    var out = [];
    for (var i = 0; i < themes.length; i++) {
        var t = themes[i];
        if (!t || typeof t.name !== "string" || t.name.length === 0)
            continue;
        out.push({
            name: t.name,
            variant: typeof t.variant === "string" ? t.variant : "",
            current: t.current === true
        });
    }
    return out;
}

// `hyprctl clients -j` -> [{ address, title, cls, workspace }], unmapped and
// hidden clients dropped, most recently focused first (focusHistoryID 0 is
// the focused window). Malformed output yields [].
function parseClients(text) {
    var parsed;
    try {
        parsed = JSON.parse(String(text == null ? "" : text));
    } catch (e) {
        return [];
    }
    if (!Array.isArray(parsed))
        return [];
    var out = [];
    for (var i = 0; i < parsed.length; i++) {
        var c = parsed[i];
        if (!c || typeof c.address !== "string" || c.address.length === 0)
            continue;
        if (c.mapped === false || c.hidden === true)
            continue;
        var cls = typeof c.class === "string" ? c.class : "";
        var title = typeof c.title === "string" && c.title.length > 0 ? c.title : cls;
        out.push({
            address: c.address,
            title: title,
            cls: cls,
            workspace: c.workspace && c.workspace.name != null ? String(c.workspace.name) : "",
            focus: typeof c.focusHistoryID === "number" ? c.focusHistoryID : Infinity,
            order: i
        });
    }
    out.sort(function (a, b) {
        return (a.focus - b.focus) || (a.order - b.order);
    });
    return out;
}

// `qalc -t <expr>` stdout -> the answer line ("" when there is none). qalc
// prints the terse result on the last non-empty line.
function parseCalc(text) {
    var lines = String(text == null ? "" : text).split("\n");
    for (var i = lines.length - 1; i >= 0; i--) {
        var line = lines[i].trim();
        if (line.length > 0)
            return line;
    }
    return "";
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        PREFIXES: PREFIXES,
        MODES: MODES,
        POWER_ACTIONS: POWER_ACTIONS,
        SUBTITLE_PENALTY: SUBTITLE_PENALTY,
        prefixFor: prefixFor,
        route: route,
        rank: rank,
        parseThemes: parseThemes,
        parseClients: parseClients,
        parseCalc: parseCalc
    };
