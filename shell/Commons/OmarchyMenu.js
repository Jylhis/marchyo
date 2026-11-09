// The command menu tree (Commons/MenuModel.build of menu.json merged with
// menu.local.json) rendered as omarchy's omarchy-menu.jsonc, the schema of the
// omarchy.menu plugin. omarchy orders rows by key order, so the file is one
// entry per line in tree order. `keys` are the keybinding cheat sheet rows
// (~/.config/marchyo/keybindings.json); a `launcher` entry with target `keys`
// becomes a submenu of those binds, routable as "keys".
//
// Dual citizenship like MenuModel.js: QML imports this file and ignores the
// CommonJS guard, Node loads it in tests/shell/omarchy-menu-test.js. Stay pure
// and never add a `.pragma` directive.

// Nerd Font glyphs for the themed icon names marchyo.menu.entries uses.
var GLYPHS = {
    "applications-all": "󰀻",
    "applications-development": "",
    "audio-card": "",
    "audio-input-microphone": "",
    "battery": "",
    "bluetooth": "",
    "camera-photo": "",
    "color-select": "󰃉",
    "computer": "",
    "cpu": "",
    "dialog-information": "",
    "draw-freehand": "",
    "edit-find": "󰴑",
    "emblem-shared": "",
    "go-next": "",
    "image-x-generic": "",
    "input-keyboard": "",
    "media-playback-stop": "",
    "media-record": "",
    "network-wireless": "",
    "preferences-desktop-font": "",
    "preferences-desktop-locale": "",
    "preferences-desktop-theme": "󰏘",
    "preferences-desktop-wallpaper": "",
    "preferences-other": "",
    "preferences-system": "󰔎",
    "system-lock-screen": "",
    "system-log-out": "󰍃",
    "system-reboot": "󰜉",
    "system-shutdown": "",
    "system-suspend": "󰒲",
    "system-suspend-hibernate": "󰤁",
    "video-display": "󰍹",
    "view-refresh": ""
};

// Providers omarchy.menu has no runtime source for open the native panel.
var NATIVE_PROVIDERS = {
    "themes": "marchyo shell open themes",
    "wallpapers": "marchyo shell open backgrounds",
    "agents": "marchyo shell open agents"
};

// A themed icon name maps to its glyph; anything else is already one.
function glyph(icon) {
    var name = String(icon || "");
    if (/^[a-z0-9-]+$/.test(name))
        return Object.prototype.hasOwnProperty.call(GLYPHS, name) ? GLYPHS[name] : "";
    return name;
}

// POSIX shell quoting, leaving words of safe characters bare.
function shellArg(value) {
    var s = String(value);
    if (/^[A-Za-z0-9,._+:@%\/-]+$/.test(s))
        return s;
    return "'" + s.replace(/'/g, "'\\''") + "'";
}

function isKeys(e) {
    return e.action === "launcher" && e.target === "keys";
}

function kindFields(e) {
    if (e.action === "exec")
        return { action: e.target };
    if (e.action === "terminal")
        return { action: "marchyo launch floating-terminal sh -c " + shellArg(e.target) };
    if (isKeys(e))
        return { aliases: ["keys"] };
    if (e.action === "launcher")
        return { action: "marchyo shell launcher " + shellArg(e.target) };
    if (e.action === "provider" && Object.prototype.hasOwnProperty.call(NATIVE_PROVIDERS, e.provider))
        return { action: NATIVE_PROVIDERS[e.provider] };
    if (e.action === "provider")
        return { provider: e.provider };
    return {};
}

function fields(e) {
    var row = { label: e.label };
    var icon = glyph(e.icon);
    if (icon !== "")
        row.icon = icon;
    if (e.aliases.length > 0)
        row.searchTerms = e.aliases.slice();
    if (e.description !== "")
        row.description = e.description;
    if (e.when !== "")
        row.when = e.when;
    if (e.checked !== "")
        row.checked = e.checked;
    var kind = kindFields(e);
    for (var k in kind)
        row[k] = kind[k];
    return row;
}

function pad3(n) {
    var s = String(n);
    while (s.length < 3)
        s = "0" + s;
    return s;
}

function keyRows(parent, keys) {
    var out = [];
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i] || {};
        var dispatch = typeof k.dispatch === "string" && k.dispatch !== "" ? k.dispatch : "";
        out.push([parent + "." + pad3(i + 1), {
            label: String(k.combo || "") + "  " + String(k.description || ""),
            searchTerms: [String(k.group || "")],
            action: dispatch !== "" ? "sleep 0.2; hyprctl dispatch " + shellArg(dispatch) : ":"
        }]);
    }
    return out;
}

// [[id, row], ..] in tree order, disabled entries and their subtrees left out.
function rows(model, keys) {
    var out = [];
    var sheet = Array.isArray(keys) ? keys : [];
    function walk(parent) {
        var ids = model.children[parent] || [];
        for (var i = 0; i < ids.length; i++) {
            var e = model.entries[ids[i]];
            if (e.disabled)
                continue;
            out.push([e.id, fields(e)]);
            if (isKeys(e))
                out = out.concat(keyRows(e.id, sheet));
            walk(e.id);
        }
    }
    walk("");
    return out;
}

function render(model, keys) {
    return "{\n" + rows(model, keys).map(function (r) {
        return "  " + JSON.stringify(r[0]) + ": " + JSON.stringify(r[1]);
    }).join(",\n") + "\n}\n";
}

if (typeof module !== "undefined")
    module.exports = {
        glyph: glyph,
        shellArg: shellArg,
        rows: rows,
        render: render
    };
