// Pure logic of the command menu (Launcher/MenuProvider): the entry tree read
// from ~/.config/marchyo/menu.json and its per-key user overlay, route
// walking, row building, guard batching and search.
//
// Dual citizenship like Format.js: QML imports this file and ignores the
// CommonJS guard, Node loads it in tests/shell/menu-test.js. Stay pure (no Qt
// types, no I/O) and never add a `.pragma` directive. Fuzzy matching comes in
// as a function (matchFn(text, query) -> { score, positions } | null).
//
// An entry (menu.json value, keyed by dotted id; the parent of `a.b` is `a`,
// a top-level id is a child of the root ""):
//   label, icon, order, action (submenu|exec|terminal|launcher|provider),
//   target, provider, aliases, description, when, checked, disabled
// `when` and `checked` are shell commands; exit 0 means true.

var ACTIONS = ["submenu", "exec", "terminal", "launcher", "provider"];

var PROVIDERS = ["apps", "themes", "wallpapers", "fonts", "power-profiles", "languages"];

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Overlay merge, per key and per field. An overlay value of null removes the
// key; a key the base lacks is added.
function mergeOverlay(base, overlay) {
    var out = {};
    var k;
    for (k in base)
        out[k] = base[k];
    if (!isObject(overlay))
        return out;
    for (k in overlay) {
        var o = overlay[k];
        if (o === null) {
            delete out[k];
        } else if (isObject(o)) {
            var merged = {};
            var f;
            if (isObject(out[k]))
                for (f in out[k])
                    merged[f] = out[k][f];
            for (f in o)
                merged[f] = o[f];
            out[k] = merged;
        }
    }
    return out;
}

function parentOf(id) {
    var i = String(id).lastIndexOf(".");
    return i < 0 ? "" : String(id).slice(0, i);
}

function str(v, fallback) {
    return typeof v === "string" ? v : fallback;
}

// Raw entries -> { entries: {id: entry}, children: {parent: [id..]} } with
// defaults filled in and each child list sorted by order then label. Entries
// without a label are dropped.
function build(raw) {
    var entries = {};
    var id;
    for (id in raw) {
        var r = raw[id];
        if (!isObject(r) || typeof r.label !== "string" || r.label === "")
            continue;
        var action = ACTIONS.indexOf(r.action) >= 0 ? r.action : "submenu";
        entries[id] = {
            id: id,
            parent: parentOf(id),
            label: r.label,
            icon: str(r.icon, ""),
            order: typeof r.order === "number" ? r.order : 100,
            action: action,
            target: str(r.target, ""),
            provider: PROVIDERS.indexOf(r.provider) >= 0 ? r.provider : "",
            aliases: Array.isArray(r.aliases) ? r.aliases.filter(function (a) {
                return typeof a === "string";
            }) : [],
            description: str(r.description, ""),
            when: str(r.when, ""),
            checked: str(r.checked, ""),
            disabled: r.disabled === true
        };
    }
    var children = {};
    for (id in entries) {
        var p = entries[id].parent;
        if (p !== "" && !entries[p])
            continue;
        (children[p] = children[p] || []).push(id);
    }
    for (var key in children)
        children[key].sort(function (a, b) {
            var ea = entries[a], eb = entries[b];
            if (ea.order !== eb.order)
                return ea.order - eb.order;
            return ea.label < eb.label ? -1 : ea.label > eb.label ? 1 : a < b ? -1 : 1;
        });
    return {
        entries: entries,
        children: children
    };
}

function isMenu(model, id) {
    var e = model.entries[id];
    return !!e && (e.action === "provider" || (model.children[id] || []).length > 0);
}

// The deepest existing menu on the way to `route`: the route itself when it
// is a submenu or provider, else its nearest such ancestor, else the root "".
function resolveRoute(model, route) {
    var r = String(route == null ? "" : route);
    while (r !== "") {
        if (isMenu(model, r))
            return r;
        r = parentOf(r);
    }
    return "";
}

// [{ id, label }] from the first level down to `route`.
function breadcrumb(model, route) {
    var out = [];
    var r = String(route == null ? "" : route);
    while (r !== "" && model.entries[r]) {
        out.unshift({
            id: r,
            label: model.entries[r].label
        });
        r = parentOf(r);
    }
    return out;
}

// Guards of the entries in `ids`, as [{ id, kind: "when"|"checked", cmd }].
function guardsFor(model, ids) {
    var out = [];
    for (var i = 0; i < ids.length; i++) {
        var e = model.entries[ids[i]];
        if (!e)
            continue;
        if (e.when !== "")
            out.push({
                id: e.id,
                kind: "when",
                cmd: e.when
            });
        if (e.checked !== "")
            out.push({
                id: e.id,
                kind: "checked",
                cmd: e.checked
            });
    }
    return out;
}

// One `sh -c` argv that runs every guard in a subshell and prints the indices
// of those that exit 0, one per line. The guard commands travel as positional
// arguments, never spliced into the script.
function guardArgv(guards) {
    var script = 'i=0; for g in "$@"; do ( eval "$g" ) >/dev/null 2>&1 </dev/null && echo "$i"; i=$((i+1)); done';
    var argv = ["sh", "-c", script, "sh"];
    for (var i = 0; i < guards.length; i++)
        argv.push(guards[i].cmd);
    return argv;
}

// Guard output (indices) -> { when: {id: true}, checked: {id: true} } over
// the guards that passed. Entries with a `when` guard that is absent from
// `when` are hidden; see visible().
function parseGuardOutput(guards, text) {
    var passed = {};
    var lines = String(text == null ? "" : text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var n = parseInt(lines[i], 10);
        if (isFinite(n) && n >= 0 && n < guards.length)
            passed[n] = true;
    }
    var out = {
        when: {},
        checked: {}
    };
    for (var j = 0; j < guards.length; j++)
        if (passed[j])
            out[guards[j].kind][guards[j].id] = true;
    return out;
}

// An entry with a `when` guard shows only after the guard passed. Before the
// guards ran (state null) guarded entries stay hidden, so nothing flashes.
function visible(entry, state) {
    if (entry.when === "")
        return true;
    return !!state && state.when[entry.id] === true;
}

function rowOf(model, entry, state, trail) {
    var isSub = isMenu(model, entry.id);
    return {
        id: entry.id,
        title: entry.label,
        subtitle: trail !== undefined ? trail : entry.description,
        icon: entry.icon,
        action: entry.action,
        target: entry.target,
        provider: entry.provider,
        submenu: isSub,
        checked: !!state && state.checked[entry.id] === true,
        disabled: entry.disabled,
        aliases: entry.aliases,
        description: entry.description,
        score: 0,
        positions: []
    };
}

// The rows of one menu level, guards applied.
function levelRows(model, route, state) {
    var ids = model.children[route] || [];
    var rows = [];
    for (var i = 0; i < ids.length; i++) {
        var e = model.entries[ids[i]];
        if (visible(e, state))
            rows.push(rowOf(model, e, state));
    }
    return rows;
}

// Every id below `route`, depth first (the set a search covers and the guard
// batch needs).
function descendants(model, route) {
    var out = [];
    var stack = (model.children[route] || []).slice().reverse();
    while (stack.length > 0) {
        var id = stack.pop();
        out.push(id);
        var kids = (model.children[id] || []).slice().reverse();
        for (var i = 0; i < kids.length; i++)
            stack.push(kids[i]);
    }
    return out;
}

function pathLabel(model, id) {
    var parts = [];
    var r = parentOf(id);
    while (r !== "" && model.entries[r]) {
        parts.unshift(model.entries[r].label);
        r = parentOf(r);
    }
    return parts.join(" > ");
}

// Search below `route`: leaves and provider entries whose label, aliases or
// description match, best first, each row carrying its menu path as subtitle.
// Plain submenus are skipped (their entries are listed themselves).
function searchRows(model, route, query, state, matchFn) {
    var q = String(query == null ? "" : query).trim();
    var ids = descendants(model, route);
    var out = [];
    for (var i = 0; i < ids.length; i++) {
        var e = model.entries[ids[i]];
        if (!visible(e, state))
            continue;
        if (isMenu(model, e.id) && e.action !== "provider")
            continue;
        var best = -1;
        var positions = [];
        var byLabel = matchFn(e.label, q);
        if (byLabel) {
            best = byLabel.score;
            positions = byLabel.positions;
        }
        for (var a = 0; a < e.aliases.length; a++) {
            var byAlias = matchFn(e.aliases[a], q);
            if (byAlias && byAlias.score - 100 > best) {
                best = byAlias.score - 100;
                positions = [];
            }
        }
        if (e.description) {
            var byDesc = matchFn(e.description, q);
            if (byDesc && byDesc.score - 300 > best) {
                best = byDesc.score - 300;
                positions = [];
            }
        }
        if (best < 0 && !byLabel)
            continue;
        var row = rowOf(model, e, state, pathLabel(model, e.id));
        row.score = best;
        row.positions = positions;
        row.order = i;
        out.push(row);
    }
    out.sort(function (x, y) {
        return (y.score - x.score) || (x.order - y.order);
    });
    return out;
}

// ---- dynamic providers -----------------------------------------------------
//
// Each provider lists items with one `marchyo` command and applies one with
// another; `apps` is native (DesktopEntries) and has no command. Every item is
// { title, subtitle, icon, checked, argv } where argv runs after `marchyo`.

function parseJson(text) {
    try {
        return JSON.parse(String(text == null ? "" : text));
    } catch (e) {
        return null;
    }
}

var PROVIDER_SPECS = {
    "themes": {
        list: ["theme", "list", "--format", "json"],
        icon: "preferences-desktop-theme",
        parse: function (text) {
            var j = parseJson(text);
            var items = j && Array.isArray(j.themes) ? j.themes : [];
            return items.filter(function (t) {
                return t && typeof t.name === "string" && t.name !== "";
            }).map(function (t) {
                return {
                    title: t.name,
                    subtitle: typeof t.variant === "string" ? t.variant : "",
                    checked: t.current === true,
                    argv: ["theme", "set", t.name]
                };
            });
        }
    },
    "fonts": {
        list: ["font", "list", "--format", "json"],
        icon: "preferences-desktop-font",
        parse: function (text) {
            var j = parseJson(text);
            var items = j && Array.isArray(j.fonts) ? j.fonts : [];
            return items.filter(function (f) {
                return typeof f === "string" && f !== "";
            }).map(function (f) {
                return {
                    title: f,
                    subtitle: "",
                    checked: false,
                    argv: ["font", "set", f]
                };
            });
        }
    },
    "languages": {
        list: ["language", "list", "--format", "json"],
        icon: "preferences-desktop-locale",
        parse: function (text) {
            var j = parseJson(text);
            var items = j && Array.isArray(j.languages) ? j.languages : [];
            return items.filter(function (l) {
                return l && typeof l.code === "string" && l.code !== "";
            }).map(function (l) {
                return {
                    title: typeof l.englishName === "string" && l.englishName ? l.englishName : l.code,
                    subtitle: typeof l.name === "string" ? l.name : "",
                    checked: l.current === true,
                    argv: ["language", l.code]
                };
            });
        }
    },
    "power-profiles": {
        list: ["powerprofile", "list"],
        icon: "preferences-system-power",
        parse: function (text) {
            var out = [];
            var lines = String(text == null ? "" : text).split("\n");
            for (var i = 0; i < lines.length; i++) {
                var m = /^([* ])\s*([a-z][a-z-]*):\s*$/.exec(lines[i]) || /^\s*([a-z][a-z-]*):\s*$/.exec(lines[i]);
                if (!m)
                    continue;
                var name = m.length === 3 ? m[2] : m[1];
                out.push({
                    title: name,
                    subtitle: "",
                    checked: m.length === 3 && m[1] === "*",
                    argv: ["powerprofile", "set", name]
                });
            }
            return out;
        }
    },
    "wallpapers": {
        list: ["bg", "list"],
        icon: "preferences-desktop-wallpaper",
        parse: function (text) {
            return String(text == null ? "" : text).split("\n").map(function (l) {
                return l.trim();
            }).filter(function (l) {
                return l !== "";
            }).map(function (l) {
                return {
                    title: l.split("/").pop(),
                    subtitle: "",
                    checked: false,
                    argv: ["bg", "set", l]
                };
            });
        }
    }
};

// ---- raw JSON text ---------------------------------------------------------

function parseEntries(text) {
    var j = parseJson(text);
    return isObject(j) ? j : {};
}

// ---- keybinding cheat sheet ------------------------------------------------

var PLANES = ["Super", "Super+Shift", "Super+Ctrl", "Super+Alt", "Super+Ctrl+Alt", "Other"];

// The modifier plane of a chord such as "SUPER + CTRL + A".
function planeOf(combo) {
    var parts = String(combo).split("+").map(function (p) {
        return p.trim().toUpperCase();
    });
    var mods = parts.slice(0, -1);
    function has(m) {
        return mods.indexOf(m) >= 0;
    }
    if (!has("SUPER"))
        return "Other";
    var shift = has("SHIFT"), ctrl = has("CTRL"), alt = has("ALT");
    if (ctrl && alt)
        return "Super+Ctrl+Alt";
    if (ctrl)
        return "Super+Ctrl";
    if (alt)
        return "Super+Alt";
    if (shift)
        return "Super+Shift";
    return "Super";
}

// keybindings.json ([{ combo, description, group, dispatch? }]) -> rows grouped
// by plane (in PLANES order, table order within a plane). Rows without a
// `dispatch` stay listed but cannot run.
function sheetRows(entries) {
    var list = Array.isArray(entries) ? entries : [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (!isObject(e) || typeof e.combo !== "string" || typeof e.description !== "string")
            continue;
        var plane = planeOf(e.combo);
        out.push({
            title: e.description,
            subtitle: plane,
            chord: e.combo,
            trailing: e.combo,
            plane: plane,
            group: str(e.group, ""),
            dispatch: typeof e.dispatch === "string" ? e.dispatch : "",
            order: i,
            score: 0,
            positions: []
        });
    }
    out.sort(function (a, b) {
        return (PLANES.indexOf(a.plane) - PLANES.indexOf(b.plane)) || (a.order - b.order);
    });
    return out;
}

// Search covers the description and the chord (separators ignored: "ctrl a"
// finds "SUPER + CTRL + A").
function searchSheet(rows, query, matchFn) {
    var q = String(query == null ? "" : query).trim();
    if (q === "")
        return rows;
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        var byTitle = matchFn(r.title, q);
        var chord = r.chord.replace(/\s*\+\s*/g, " ");
        var byChord = matchFn(chord, q);
        if (!byTitle && !byChord)
            continue;
        var copy = {};
        for (var k in r)
            copy[k] = r[k];
        copy.score = Math.max(byTitle ? byTitle.score : -Infinity, byChord ? byChord.score - 100 : -Infinity);
        copy.positions = byTitle ? byTitle.positions : [];
        out.push(copy);
    }
    out.sort(function (a, b) {
        return (b.score - a.score) || (a.order - b.order);
    });
    return out;
}

if (typeof module !== "undefined")
    module.exports = {
        ACTIONS: ACTIONS,
        PROVIDERS: PROVIDERS,
        PROVIDER_SPECS: PROVIDER_SPECS,
        PLANES: PLANES,
        mergeOverlay: mergeOverlay,
        parentOf: parentOf,
        build: build,
        isMenu: isMenu,
        resolveRoute: resolveRoute,
        breadcrumb: breadcrumb,
        guardsFor: guardsFor,
        guardArgv: guardArgv,
        parseGuardOutput: parseGuardOutput,
        visible: visible,
        levelRows: levelRows,
        descendants: descendants,
        searchRows: searchRows,
        parseEntries: parseEntries,
        planeOf: planeOf,
        sheetRows: sheetRows,
        searchSheet: searchSheet
    };
