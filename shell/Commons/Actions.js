// Dispatch into shell.qml's `actions` table, and the parser for
// shell/shortcuts.json. Pure, so tests/shell/actions-test.js can load it under
// Node.

function lookup(table, name) {
    if (!Object.prototype.hasOwnProperty.call(table, name))
        return null;
    return typeof table[name] === "function" ? table[name] : null;
}

// Run `name` from `table` when its arity matches the argument count.
// {ran, output}; nothing runs for an unknown name or the wrong arity.
function call(table, name, args) {
    var fn = lookup(table, name);
    var argv = args || [];
    if (fn === null || fn.length !== argv.length)
        return {
            ran: false
        };
    var out = fn.apply(null, argv);
    return {
        ran: true,
        output: out === undefined || out === null ? "" : String(out)
    };
}

// shell/shortcuts.json: [{name, call, args, description}]. Malformed entries
// are dropped, so one bad line cannot unregister the rest.
function parseShortcuts(text) {
    var list;
    try {
        list = JSON.parse(String(text || "[]"));
    } catch (e) {
        return [];
    }
    if (!Array.isArray(list))
        return [];
    var out = [];
    var seen = {};
    for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (!e || typeof e.name !== "string" || !/^[A-Za-z][A-Za-z0-9.]*$/.test(e.name))
            continue;
        if (typeof e.call !== "string" || seen[e.name])
            continue;
        var args = Array.isArray(e.args) ? e.args.map(String) : [];
        seen[e.name] = true;
        out.push({
            name: e.name,
            call: e.call,
            args: args,
            description: typeof e.description === "string" ? e.description : e.name
        });
    }
    return out;
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        lookup: lookup,
        call: call,
        parseShortcuts: parseShortcuts
    };
