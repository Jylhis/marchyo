import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/LauncherProviders.js" as Providers

// `marchyo menu select` and `marchyo menu input`: the CLI writes a request file
// under $XDG_RUNTIME_DIR/marchyo/menu/ and calls the shell's menuRequest. The
// answer goes to the sibling `.out` file and `.done` is touched last; closing
// the launcher without a choice answers with an empty file (a cancel).
//   select  rows { glyph, label, subtext }; the value is the label, or
//           "label<TAB>subtext" for a row with subtext; --multiple toggles rows
//           and a final "Apply" row returns a JSON array of values.
//   input   the typed line is the value.
Provider {
    id: root

    providerId: "dmenu"
    selectOnEmpty: true

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string path: Launcher.dmenuPath
    readonly property bool pathOk: root.runtimeDir !== "" && root.path.indexOf(root.runtimeDir + "/marchyo/menu/") === 0 && /^[A-Za-z0-9._\/-]+\.json$/.test(root.path) && root.path.indexOf("..") === -1

    readonly property var requestFile: FileView {
        path: root.pathOk ? root.path : ""
        blockLoading: true
        printErrors: false
    }

    readonly property var request: {
        try {
            const r = JSON.parse(requestFile.text() || "{}");
            return r && typeof r === "object" ? r : {};
        } catch (e) {
            return {};
        }
    }
    readonly property bool inputMode: root.request.mode === "input"
    readonly property bool multiple: root.request.multiple === true
    readonly property string promptText: typeof root.request.prompt === "string" ? root.request.prompt : ""

    property var picked: []
    property bool answered: false

    onActiveChanged: {
        if (root.active) {
            root.answered = false;
            root.picked = Array.isArray(root.request.selected) ? root.request.selected.slice() : [];
        } else if (!root.answered && root.pathOk && root.request.mode) {
            root.finish("");
        }
    }

    function valueOf(row) {
        return row.subtext ? row.label + "\t" + row.subtext : row.label;
    }

    // Answer the request: out first, then done, in one shell so a poller that
    // sees .done always finds the complete .out.
    function finish(text) {
        if (root.answered || !root.pathOk)
            return;
        root.answered = true;
        const base = root.path.replace(/\.json$/, "");
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\" && : > \"$3\"", "sh", text, base + ".out", base + ".done"]);
        Launcher.close();
    }

    function toggle(value) {
        const next = root.picked.slice();
        const i = next.indexOf(value);
        if (i >= 0)
            next.splice(i, 1);
        else
            next.push(value);
        root.picked = next;
        const cmd = root.request.onChange;
        if (Array.isArray(cmd) && cmd.length > 0)
            Quickshell.execDetached(cmd.concat([JSON.stringify(next)]));
    }

    readonly property var rows: {
        if (root.inputMode)
            return [];
        const list = Array.isArray(root.request.rows) ? root.request.rows : [];
        const out = list.filter(r => r && typeof r.label === "string").map(r => {
            const value = root.valueOf(r);
            const on = root.picked.indexOf(value) >= 0;
            return {
                "title": (r.glyph ? r.glyph + "  " : "") + r.label,
                "plain": r.label,
                "subtitle": r.subtext || "",
                "icon": "",
                "trailing": on ? "✓" : "",
                "checked": on,
                "score": 0,
                "positions": [],
                "activate": () => root.multiple ? root.toggle(value) : root.finish(value)
            };
        });
        if (root.multiple)
            out.push({
                "title": I18n.t("launcher.dmenuApply"),
                "plain": "",
                "subtitle": "",
                "icon": "",
                "trailing": "",
                "score": 0,
                "positions": [],
                "activate": () => root.finish(JSON.stringify(root.picked))
            });
        return out;
    }

    results: {
        if (root.inputMode)
            return [
                {
                    "title": root.query,
                    "subtitle": "",
                    "icon": "",
                    "trailing": "",
                    "score": 0,
                    "positions": [],
                    "activate": () => {
                        if (root.query.trim() !== "")
                            root.finish(root.query);
                    }
                }
            ];
        return Providers.rank(root.rows, root.query, (text, q) => Fuzzy.match(text, q));
    }
}
