import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/Cliphist.js" as Cliphist

// Clipboard history over `cliphist list` (fed by the wl-paste watchers in
// modules/home/hyprland.nix). Rerun per activation is a refresh, not a poll;
// rows decode in Commons/Cliphist.js. Text only; binary/image rows are
// skipped. Rows keep cliphist's newest-first order; the query filters.
Provider {
    id: root

    providerId: "clipboard"
    maxRows: 12
    showIcons: false
    compact: true
    highlight: false
    selectOnEmpty: true
    emptyText: "clipboard history is empty"

    readonly property int maxHistory: 500

    property var items: []

    results: {
        const q = root.query.trim();
        const out = [];
        for (let i = 0; i < root.items.length && out.length < root.maxRows; i++) {
            const it = root.items[i];
            if (q.length === 0 || Fuzzy.score(it.prepared, q) >= 0)
                out.push(it);
        }
        return out;
    }

    function rowFor(text) {
        return {
            title: text,
            subtitle: "",
            prepared: Fuzzy.prepare(text),
            icon: "",
            score: 0,
            positions: [],
            activate: () => {
                Launcher.close();
                Launcher.pasteText(text);
            }
        };
    }

    readonly property var listProc: Process {
        id: listProc
        command: [Config.cliphist, "list"]
        stdout: SplitParser {
            onRead: line => {
                const parsed = Cliphist.parseLine(line);
                if (parsed && root.items.length < root.maxHistory)
                    root.items = root.items.concat(root.rowFor(parsed.text));
            }
        }
    }

    onActiveChanged: {
        if (root.active) {
            root.items = [];
            listProc.running = false;
            listProc.running = true;
        }
    }
}
