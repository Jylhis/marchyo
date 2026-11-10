import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/LauncherProviders.js" as Providers

// ">font" switcher: lists the monospace and UI font families once per
// activation (`marchyo font list --kind mono|ui`) and applies the chosen one
// live with `marchyo font set <family> --kind <kind>`. A leading "mono" or
// "ui" word in the query narrows the list to that kind.
Provider {
    id: root

    providerId: "font"
    prefix: Providers.prefixFor("font")
    selectOnEmpty: true
    emptyText: root.loading > 0 ? I18n.t("launcher.loadingFonts") : I18n.t("launcher.noFonts")

    property var mono: []
    property var ui: []
    property int loading: 0

    readonly property var split: Providers.splitFontKind(root.query)

    readonly property var rows: root.mono.concat(root.ui).filter(f => root.split.kind === "" || f.kind === root.split.kind).map(f => ({
                title: f.family,
                subtitle: f.current ? I18n.t("launcher.fontCurrent", f.kind) : f.kind,
                icon: "preferences-desktop-font",
                score: 0,
                positions: [],
                activate: () => {
                    Launcher.close();
                    Quickshell.execDetached([Config.marchyo, "font", "set", f.family, "--kind", f.kind]);
                }
            }))

    results: Providers.rank(root.rows, root.split.query, (text, q) => Fuzzy.match(text, q))

    onActiveChanged: {
        if (root.active) {
            root.loading = 2;
            root.monoProc.running = false;
            root.monoProc.running = true;
            root.uiProc.running = false;
            root.uiProc.running = true;
        }
    }

    // A family list is a few KiB; refuse anything absurd.
    readonly property int maxChars: 1024 * 1024

    readonly property var monoProc: Process {
        command: [Config.marchyo, "font", "list", "--kind", "mono", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.mono = text.length <= root.maxChars ? Providers.parseFonts(text).fonts : [];
                root.loading = Math.max(0, root.loading - 1);
            }
        }
    }

    readonly property var uiProc: Process {
        command: [Config.marchyo, "font", "list", "--kind", "ui", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ui = text.length <= root.maxChars ? Providers.parseFonts(text).fonts : [];
                root.loading = Math.max(0, root.loading - 1);
            }
        }
    }
}
