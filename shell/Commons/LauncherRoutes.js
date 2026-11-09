// Where a launcher mode goes while a plugin replaces its native role
// (`replaces` in the plugin manifest, Commons/PluginIndex.replacementFor).
// Services/Launcher.qml imports this from QML, tests/shell/launcher-routes-test.js
// loads it from Node. Pure functions only and no `.pragma` line.
//
// The payloads follow omarchy's plugin contract: omarchy.menu opens a route
// from `{ menu }` and answers a dmenu request from `{ mode, options, ... }`.

// Native role of each launcher mode.
var ROLES = {
    "emoji": "launcher.emoji",
    "clipboard": "launcher.clipboard"
};

// Menu route of each mode the replacing menu shows as a submenu.
var MENU_ROUTES = {
    "apps": "apps",
    "font": "appearance.font",
    "keys": "keys"
};

function roleOf(mode) {
    return ROLES[mode] || "launcher";
}

// { plugin, payload } to summon, { panel } to open a native panel instead, or
// null while the native launcher owns `mode`. `route` is the menu id of the
// "menu" mode ("" is the root). `replacementFor(role)` is the plugin id or "".
function target(mode, route, replacementFor) {
    var plugin = replacementFor(roleOf(mode));
    if (plugin === "")
        return null;
    if (mode === "theme")
        return {
            panel: "themes"
        };
    if (mode === "menu")
        return {
            plugin: plugin,
            payload: {
                menu: route === "" ? "root" : route
            }
        };
    if (MENU_ROUTES[mode])
        return {
            plugin: plugin,
            payload: {
                menu: MENU_ROUTES[mode]
            }
        };
    return {
        plugin: plugin,
        payload: {}
    };
}

// The request files `marchyo menu select|input` writes: a JSON file under
// $XDG_RUNTIME_DIR/marchyo/menu/ (Launcher/DmenuProvider checks the same).
function dmenuPathOk(path, runtimeDir) {
    return runtimeDir !== "" && path.indexOf(runtimeDir + "/marchyo/menu/") === 0 && /^[A-Za-z0-9._\/-]+\.json$/.test(path) && path.indexOf("..") === -1;
}

// One request row as an omarchy option: "label", "glyph\tlabel" or
// "glyph\tlabel\tsubtext". omarchy drops the first field when there are two or
// more, so a row with subtext always carries the glyph field, empty or not;
// the value it returns is then "label\tsubtext", as the native mode answers.
function optionOf(row) {
    var glyph = typeof row.glyph === "string" ? row.glyph : "";
    var subtext = typeof row.subtext === "string" ? row.subtext : "";
    if (subtext !== "")
        return glyph + "\t" + row.label + "\t" + subtext;
    return glyph !== "" ? glyph + "\t" + row.label : row.label;
}

function stringArray(v) {
    return Array.isArray(v) && v.every(function (x) {
        return typeof x === "string";
    });
}

// The omarchy.menu payload for request `req` read from `path`; the answer goes
// to the `.out` and `.done` files beside it, as `marchyo menu` expects.
function dmenuPayload(req, path) {
    var r = req && typeof req === "object" ? req : {};
    var base = path.replace(/\.json$/, "");
    var rows = Array.isArray(r.rows) ? r.rows : [];
    var payload = {
        mode: r.mode === "input" ? "input" : "select",
        prompt: typeof r.prompt === "string" ? r.prompt : "",
        options: rows.filter(function (row) {
            return row && typeof row.label === "string";
        }).map(optionOf),
        multiple: r.multiple === true,
        selected: stringArray(r.selected) ? r.selected : [],
        selectionFile: base + ".out",
        doneFile: base + ".done"
    };
    if (typeof r.width === "number")
        payload.width = r.width;
    if (typeof r.maxHeight === "number")
        payload.maxHeight = r.maxHeight;
    if (stringArray(r.onChange) && r.onChange.length > 0)
        payload.onChange = r.onChange;
    if (typeof r.changeKey === "string")
        payload.changeKey = r.changeKey;
    return payload;
}

if (typeof module !== "undefined")
    module.exports = {
        roleOf: roleOf,
        target: target,
        dmenuPathOk: dmenuPathOk,
        optionOf: optionOf,
        dmenuPayload: dmenuPayload
    };
