// Pure helpers for the plugin host (Services/PluginHost, Commons/PluginIndex):
// dev plugin index validation, the public manifest handed to a plugin, and the
// summon scope rules.
//
// Dual citizenship like Format.js: QML imports this file and ignores the
// CommonJS guard, Node loads it in tests/shell/plugin-manifest-test.js. Stay
// pure (no Qt types, no I/O) and never add a `.pragma` directive.

var HOST_KINDS = ["panel", "menu", "overlay"];

// Kinds the dev loader may mount. `service`, `daemon` and `bar` run at startup
// or replace the bar, so they need a rebuild.
var DEV_KINDS = ["bar-widget", "panel", "overlay", "menu", "launcher"];

var ENTRY_KEYS = {
    "bar-widget": "barWidget",
    "launcher": "launcher",
    "daemon": "daemon",
    "bar": "bar",
    "panel": "panel",
    "menu": "menu",
    "overlay": "overlay",
    "service": "service"
};

var RESERVED_PREFIXES = ["marchyo.", "omarchy."];

function hasKind(entry, kind) {
    return !!entry && Array.isArray(entry.kinds) && entry.kinds.indexOf(kind) !== -1;
}

// A panel, menu or overlay plugin: summoned through a Loader.
function isHosted(entry) {
    for (var i = 0; i < HOST_KINDS.length; i++)
        if (hasKind(entry, HOST_KINDS[i]))
            return true;
    return false;
}

// A bar widget the bar mounts: summoning goes to the live widget's open().
function isBarWidgetOnly(entry) {
    return hasKind(entry, "bar-widget") && !isHosted(entry);
}

function safeRelative(path) {
    var p = String(path || "");
    return p !== "" && p.charAt(0) !== "/" && p.indexOf("..") === -1 && p.indexOf("\0") === -1 && p.indexOf("://") === -1;
}

function stringList(v) {
    if (!Array.isArray(v))
        return [];
    return v.filter(function (x) {
        return typeof x === "string";
    });
}

// The id of the first plugin entry whose `replaces` names `role`, or "".
function replacementFor(entries, role) {
    for (var i = 0; i < entries.length; i++)
        if (stringList(entries[i].replaces).indexOf(role) !== -1)
            return entries[i].id;
    return "";
}

// Ids of the plugins that replace at least one native panel, minus `keepId`.
function panelReplacers(entries, keepId) {
    var out = [];
    for (var i = 0; i < entries.length; i++) {
        var replacesPanel = stringList(entries[i].replaces).some(function (r) {
            return r.indexOf("panel.") === 0;
        });
        if (replacesPanel && entries[i].id !== keepId)
            out.push(entries[i].id);
    }
    return out;
}

// The widget in `widgets` that lives on output `screenName` (by `nameOf`),
// else the first one, else null.
function pickWidget(widgets, screenName, nameOf) {
    var list = Array.isArray(widgets) ? widgets : [];
    if (screenName)
        for (var i = 0; i < list.length; i++)
            if (nameOf(list[i]) === screenName)
                return list[i];
    return list.length > 0 ? list[0] : null;
}

// One dev index entry to a plugin entry, or a string naming why it is refused.
// `devDir` is the absolute dev plugin directory; the entry points become
// file:// URLs under <devDir>/<id>/, whatever dir the index claims.
function devEntry(raw, devDir, takenIds) {
    if (!raw || typeof raw !== "object")
        return "not an object";
    var id = String(raw.id || "");
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id) || id.indexOf("..") !== -1)
        return "invalid id";
    for (var r = 0; r < RESERVED_PREFIXES.length; r++)
        if (id.indexOf(RESERVED_PREFIXES[r]) === 0)
            return "reserved namespace";
    if (takenIds.indexOf(id) !== -1)
        return "id already taken";
    if (!Array.isArray(raw.kinds) || raw.kinds.length === 0)
        return "no kinds";
    for (var k = 0; k < raw.kinds.length; k++)
        if (DEV_KINDS.indexOf(raw.kinds[k]) === -1)
            return "kind '" + raw.kinds[k] + "' needs a rebuild";
    var eps = raw.entryPoints;
    if (!eps || typeof eps !== "object")
        return "no entry points";
    var urls = {};
    for (var j = 0; j < raw.kinds.length; j++) {
        var key = ENTRY_KEYS[raw.kinds[j]];
        if (!safeRelative(eps[key]))
            return "unsafe or missing entry point '" + key + "'";
        urls[key] = "file://" + devDir + "/" + id + "/" + eps[key];
    }
    return {
        id: id,
        name: String(raw.name || id),
        version: String(raw.version || "0"),
        kinds: raw.kinds.slice(),
        prefix: typeof raw.prefix === "string" ? raw.prefix : null,
        // Dev plugins never mount at shell start, whatever the manifest asks.
        keepLoaded: false,
        replaces: stringList(raw.replaces),
        barWidget: raw.barWidget && typeof raw.barWidget === "object" ? raw.barWidget : null,
        entryPoints: urls,
        dev: true
    };
}

// Parse the dev index text ({ plugins: [..] }) into { entries, refused }.
// Baked ids win: a dev entry that repeats one is refused.
function devEntries(text, devDir, bakedIds) {
    var out = { entries: [], refused: [] };
    var parsed = null;
    try {
        parsed = JSON.parse(text || "{}");
    } catch (e) {
        return out;
    }
    var list = parsed && Array.isArray(parsed.plugins) ? parsed.plugins : [];
    var taken = bakedIds.slice();
    for (var i = 0; i < list.length; i++) {
        var res = devEntry(list[i], devDir, taken);
        if (typeof res === "string") {
            out.refused.push({
                id: String(list[i] && list[i].id || "?"),
                reason: res
            });
            continue;
        }
        taken.push(res.id);
        out.entries.push(res);
    }
    return out;
}

// The manifest copy a plugin receives: no store paths, no host objects.
function publicManifest(entry) {
    if (!entry)
        return null;
    return {
        "schemaVersion": 1,
        "id": entry.id,
        "name": entry.name,
        "version": entry.version,
        "kinds": entry.kinds.slice(),
        "keepLoaded": entry.keepLoaded === true,
        "barWidget": entry.barWidget ? JSON.parse(JSON.stringify(entry.barWidget)) : null,
        "prefix": entry.prefix || null
    };
}

// May plugin `callerId` (manifest `caller`) act on `targetId`? A plugin owns
// itself; a `bar` plugin also controls the UI plugins it hosts. Nothing else.
function mayControl(caller, target) {
    if (!caller || !target)
        return false;
    if (caller.id === target.id)
        return true;
    if (!hasKind(caller, "bar"))
        return false;
    return isHosted(target) || hasKind(target, "bar-widget");
}

// firstPartyServiceFor scope: a plugin reaches its own service, and a `bar`
// plugin also the omarchy.* services the built-in widgets read, never one that
// replaces `polkit`.
function mayUseFirstPartyService(caller, target) {
    if (!caller || !target)
        return false;
    if (caller.id === target.id)
        return true;
    return hasKind(caller, "bar") && String(target.id).indexOf("omarchy.") === 0 && stringList(target.replaces).indexOf("polkit") === -1;
}

if (typeof module !== "undefined")
    module.exports = {
        HOST_KINDS: HOST_KINDS,
        DEV_KINDS: DEV_KINDS,
        hasKind: hasKind,
        isHosted: isHosted,
        isBarWidgetOnly: isBarWidgetOnly,
        safeRelative: safeRelative,
        devEntry: devEntry,
        devEntries: devEntries,
        replacementFor: replacementFor,
        panelReplacers: panelReplacers,
        pickWidget: pickWidget,
        publicManifest: publicManifest,
        mayControl: mayControl,
        mayUseFirstPartyService: mayUseFirstPartyService
    };
