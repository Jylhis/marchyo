// Image files of the omarchy.clipboard plugin that its history no longer
// references. capture.sh stores each copied image under
// $XDG_STATE_HOME/omarchy/clipboard-images and the plugin keeps only the path in
// clipboard-history.json, so clearing, deleting or evicting an entry leaves
// the file behind (Plugins/OmarchyClipboardImages.qml removes it).
//
// Dual citizenship like MenuModel.js: QML imports this file and ignores the
// CommonJS guard, Node loads it in tests/shell/clipboard-images-test.js. Stay
// pure and never add a `.pragma` directive.

// Image paths under `dir` that the history JSON text references.
function referencedImages(historyText, dir) {
    var parsed;
    try {
        parsed = JSON.parse(String(historyText || "[]"));
    } catch (e) {
        return null;
    }
    if (!Array.isArray(parsed))
        return null;
    var prefix = String(dir) + "/";
    var out = [];
    for (var i = 0; i < parsed.length; i++) {
        var e = parsed[i];
        if (e && e.type === "image" && typeof e.path === "string" && e.path.indexOf(prefix) === 0 && out.indexOf(e.path) === -1)
            out.push(e.path);
    }
    return out;
}

// find(1) argv deleting the files in `dir` that `keep` does not list. Files
// younger than a minute stay: capture.sh writes the image before the plugin
// records it.
function pruneArgv(find, dir, keep) {
    var argv = [find, dir, "-mindepth", "1", "-maxdepth", "1", "-type", "f", "-mmin", "+1"];
    for (var i = 0; i < keep.length; i++)
        argv.push("!", "-path", keep[i]);
    argv.push("-delete");
    return argv;
}

if (typeof module !== "undefined")
    module.exports = {
        referencedImages: referencedImages,
        pruneArgv: pruneArgv
    };
