import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/LauncherProviders.js" as Providers

// ">theme" switcher: lists `marchyo theme list` once per activation and
// applies the chosen theme live with `marchyo theme set <name>`.
Provider {
    id: root

    providerId: "theme"
    prefix: Providers.prefixFor("theme")
    selectOnEmpty: true
    emptyText: root.loading ? "loading themes" : "no themes"

    property var themes: []
    property bool loading: false

    readonly property var rows: root.themes.map(t => ({
                title: t.name,
                subtitle: t.current ? t.variant + ", current" : t.variant,
                icon: "preferences-desktop-theme",
                score: 0,
                positions: [],
                activate: () => {
                    Launcher.close();
                    Quickshell.execDetached([Config.marchyo, "theme", "set", t.name]);
                }
            }))

    results: Providers.rank(root.rows, root.query, (text, q) => Fuzzy.match(text, q))

    onActiveChanged: {
        if (root.active) {
            root.loading = true;
            listProc.running = false;
            listProc.running = true;
        }
    }

    readonly property var listProc: Process {
        id: listProc
        command: [Config.marchyo, "theme", "list", "--format", "json"]
        stdout: StdioCollector {
            // A theme manifest is a few hundred bytes; refuse anything absurd.
            readonly property int maxChars: 256 * 1024
            onStreamFinished: {
                root.themes = text.length <= maxChars ? Providers.parseThemes(text) : [];
                root.loading = false;
            }
        }
    }
}
