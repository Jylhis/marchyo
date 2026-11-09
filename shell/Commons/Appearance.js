// Pure logic behind the appearance surfaces: the runtime style file, the
// wallpaper list, the thumbnail script output and the picker grid navigation.
//
// Dual citizenship like Format.js: Services/RuntimeStyle.qml, Services/Pickers.qml
// and Panels/ImagePicker.qml import this from QML, tests/shell/appearance-test.js
// loads it from Node. Pure functions only (no Qt types, no I/O) and no `.pragma`
// line (Node cannot parse one).

var BAR_POSITIONS = ["top", "bottom"];
var BAR_BACKGROUNDS = ["opaque", "glassy", "clear"];
var BACKGROUND_SOURCES = ["theme", "package", "user"];

// Longest wallpaper list or style file the shell will parse.
var MAX_CHARS = 256 * 1024;

// `$XDG_STATE_HOME/marchyo/shell/style.json` -> the four runtime switches.
// Every key is optional; an absent or invalid one reads as the declarative
// default: reduceMotion false, and "" for the other three.
function parseStyle(text) {
    var out = {
        reduceMotion: false,
        uiFont: "",
        barPosition: "",
        barBackground: ""
    };
    var parsed;
    try {
        parsed = JSON.parse(String(text == null ? "" : text));
    } catch (e) {
        return out;
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
        return out;
    out.reduceMotion = parsed.reduceMotion === true;
    if (typeof parsed.uiFont === "string")
        out.uiFont = parsed.uiFont.trim();
    if (BAR_POSITIONS.indexOf(parsed.barPosition) >= 0)
        out.barPosition = parsed.barPosition;
    if (BAR_BACKGROUNDS.indexOf(parsed.barBackground) >= 0)
        out.barBackground = parsed.barBackground;
    return out;
}

// Opacity of the bar body for a barBackground mode. "" keeps the declarative
// surface alpha; glassy never gets more opaque than 0.6.
function barAlpha(mode, surfaceAlpha) {
    if (mode === "opaque")
        return 1.0;
    if (mode === "clear")
        return 0.0;
    if (mode === "glassy")
        return Math.min(surfaceAlpha, 0.6);
    return surfaceAlpha;
}

// Which text token the bar uses: the heading ink (the highest contrast the
// theme offers) once the bar body is see-through, so labels stay readable
// over a wallpaper; the body text on a solid bar.
function barTextRole(alpha) {
    return alpha < 0.75 ? "textHeading" : "text";
}

// The background mode a double-click on empty bar space switches to.
function nextBarBackground(mode) {
    var i = BAR_BACKGROUNDS.indexOf(mode);
    return BAR_BACKGROUNDS[(i + 1) % BAR_BACKGROUNDS.length];
}

// `marchyo bg list --format json` -> [{ path, name, source, current }]. Accepts
// the bare array or an object holding it under `backgrounds`. Malformed
// output yields [].
function parseBackgrounds(text) {
    var parsed;
    try {
        parsed = JSON.parse(String(text == null ? "" : text));
    } catch (e) {
        return [];
    }
    var list = Array.isArray(parsed) ? parsed : parsed && Array.isArray(parsed.backgrounds) ? parsed.backgrounds : [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var b = list[i];
        if (!b || typeof b.path !== "string" || b.path.length === 0)
            continue;
        var base = b.path.split("/").pop();
        out.push({
            path: b.path,
            name: typeof b.name === "string" && b.name.length > 0 ? b.name : base,
            source: BACKGROUND_SOURCES.indexOf(b.source) >= 0 ? b.source : "user",
            current: b.current === true
        });
    }
    return out;
}

// One line of the thumbnail script: "<image path>\t<thumbnail path>".
function parseThumbLine(line) {
    var s = String(line == null ? "" : line);
    var cut = s.indexOf("\t");
    if (cut <= 0 || cut === s.length - 1)
        return null;
    return {
        path: s.slice(0, cut),
        thumb: s.slice(cut + 1)
    };
}

// Move the selection in a grid of `count` cells and `columns` columns. `key`
// is left, right, up, down, home or end; the result stays inside the grid.
// Up and Down keep the column and stop at the first and last row.
function step(index, key, columns, count) {
    if (count <= 0)
        return -1;
    var cols = Math.max(1, columns);
    var i = index < 0 ? 0 : Math.min(index, count - 1);
    var next = i;
    if (key === "left")
        next = i - 1;
    else if (key === "right")
        next = i + 1;
    else if (key === "up")
        next = i - cols;
    else if (key === "down")
        next = i + cols;
    else if (key === "home")
        next = 0;
    else if (key === "end")
        next = count - 1;
    if (next < 0 || next >= count)
        return key === "down" && i < count - 1 && Math.floor(i / cols) < Math.floor((count - 1) / cols) ? count - 1 : i;
    return next;
}

// Index of the first row flagged current, else 0 (-1 for an empty list).
function currentIndex(rows) {
    for (var i = 0; i < rows.length; i++)
        if (rows[i].current)
            return i;
    return rows.length > 0 ? 0 : -1;
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        BAR_POSITIONS: BAR_POSITIONS,
        BAR_BACKGROUNDS: BAR_BACKGROUNDS,
        MAX_CHARS: MAX_CHARS,
        parseStyle: parseStyle,
        barAlpha: barAlpha,
        barTextRole: barTextRole,
        nextBarBackground: nextBarBackground,
        parseBackgrounds: parseBackgrounds,
        parseThumbLine: parseThumbLine,
        step: step,
        currentIndex: currentIndex
    };
