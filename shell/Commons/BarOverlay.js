// Pure runtime edits of the bar layout: the ops `marchyo bar` writes to
// $XDG_STATE_HOME/marchyo/shell/bar-layout.json, applied over the layout that
// shell.json (or the default) resolves for an output.
//
// Dual citizenship like Format.js: Commons/ShellConfig.qml imports this, and
// tests/shell/bar-overlay-test.js loads it from Node. Pure: no Qt types, no
// I/O, inputs are never mutated, no `.pragma` line.
//
// The file is `{ "ops": [ ... ] }`, ops applied in order:
//   { op: "put",    id, section, at? }  take `id` out of every section (a
//                                       separator is not moved, it is added),
//                                       then insert it at `at` (default: end)
//   { op: "remove", id }                drop every entry with this id
//   { op: "set",    section, ids }      replace the section with these ids
//   { op: "shift",  id, by }            move the entry `by` places in its section
// A moved entry keeps its `settings`.

var SECTIONS = ["left", "centerBegin", "center", "centerEnd", "right"];
var SEPARATOR_ID = "marchyo.separator";
var MAX_OPS = 200;

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

function validId(id) {
    return typeof id === "string" && /^[A-Za-z0-9._-]{1,96}$/.test(id);
}

// File text -> the well-formed ops (anything else is dropped). Never throws.
function parseOps(text) {
    var parsed;
    try {
        parsed = JSON.parse(String(text == null ? "" : text));
    } catch (e) {
        return [];
    }
    var raw = isObject(parsed) && Array.isArray(parsed.ops) ? parsed.ops : [];
    var out = [];
    for (var i = 0; i < raw.length && out.length < MAX_OPS; i++) {
        var op = raw[i];
        if (!isObject(op))
            continue;
        if (op.op === "put" && validId(op.id) && SECTIONS.indexOf(op.section) >= 0) {
            var put = {
                op: "put",
                id: op.id,
                section: op.section
            };
            if (typeof op.at === "number" && isFinite(op.at) && op.at >= 0)
                put.at = Math.floor(op.at);
            out.push(put);
        } else if (op.op === "remove" && validId(op.id)) {
            out.push({
                op: "remove",
                id: op.id
            });
        } else if (op.op === "set" && SECTIONS.indexOf(op.section) >= 0 && Array.isArray(op.ids) && op.ids.every(validId)) {
            out.push({
                op: "set",
                section: op.section,
                ids: op.ids.slice()
            });
        } else if (op.op === "shift" && validId(op.id) && typeof op.by === "number" && isFinite(op.by)) {
            out.push({
                op: "shift",
                id: op.id,
                by: Math.trunc(op.by)
            });
        }
    }
    return out;
}

function copyLayout(layout) {
    var out = {};
    for (var i = 0; i < SECTIONS.length; i++) {
        var s = SECTIONS[i];
        out[s] = layout && Array.isArray(layout[s]) ? layout[s].slice() : [];
    }
    return out;
}

// Remove `id` from every section and return the first removed entry (so its
// settings survive a move), or null.
function take(layout, id) {
    var found = null;
    for (var i = 0; i < SECTIONS.length; i++) {
        var list = layout[SECTIONS[i]];
        layout[SECTIONS[i]] = list.filter(function (e) {
            if (e.id !== id)
                return true;
            if (found === null)
                found = e;
            return false;
        });
    }
    return found;
}

function locate(layout, id) {
    for (var i = 0; i < SECTIONS.length; i++) {
        var idx = layout[SECTIONS[i]].findIndex(function (e) {
            return e.id === id;
        });
        if (idx >= 0)
            return {
                section: SECTIONS[i],
                index: idx
            };
    }
    return null;
}

// Apply `ops` to `layout` ({ left, centerBegin, center, centerEnd, right }
// of { id, settings? } entries) and return the new layout.
function apply(layout, ops) {
    var out = copyLayout(layout);
    var list = Array.isArray(ops) ? ops : [];
    for (var i = 0; i < list.length; i++) {
        var op = list[i];
        if (op.op === "put") {
            var entry = op.id === SEPARATOR_ID ? {
                id: op.id
            } : take(out, op.id) || {
                id: op.id
            };
            var target = out[op.section];
            var at = op.at === undefined ? target.length : Math.min(op.at, target.length);
            target.splice(at, 0, entry);
        } else if (op.op === "remove") {
            take(out, op.id);
        } else if (op.op === "set") {
            var previous = {};
            for (var k = 0; k < SECTIONS.length; k++)
                out[SECTIONS[k]].forEach(function (e) {
                    previous[e.id] = e;
                });
            for (var j = 0; j < op.ids.length; j++)
                if (op.ids[j] !== SEPARATOR_ID)
                    take(out, op.ids[j]);
            out[op.section] = op.ids.map(function (id) {
                return previous[id] && id !== SEPARATOR_ID ? previous[id] : {
                    id: id
                };
            });
        } else if (op.op === "shift") {
            var at2 = locate(out, op.id);
            if (at2 === null)
                continue;
            var sec = out[at2.section];
            var to = Math.max(0, Math.min(sec.length - 1, at2.index + op.by));
            var moved = sec.splice(at2.index, 1)[0];
            sec.splice(to, 0, moved);
        }
    }
    return out;
}

// CommonJS guard: QML ignores this, Node requires it (see format-test.js).
if (typeof module !== "undefined" && module.exports)
    module.exports = {
        SECTIONS: SECTIONS,
        MAX_OPS: MAX_OPS,
        parseOps: parseOps,
        apply: apply
    };
