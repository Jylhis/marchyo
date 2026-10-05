import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/LauncherProviders.js" as Providers

// "#" window switcher: lists `hyprctl clients -j` once per activation (most
// recently focused first), searched by title and class. Activating focuses
// the window, switching to its workspace.
Provider {
    id: root

    providerId: "windows"
    prefix: Providers.prefixFor("windows")
    selectOnEmpty: true
    emptyText: "no windows"

    property var clients: []

    readonly property var rows: root.clients.map(c => ({
                title: c.title,
                subtitle: c.workspace.length > 0 ? c.cls + " · workspace " + c.workspace : c.cls,
                icon: c.cls.toLowerCase(),
                score: 0,
                positions: [],
                activate: () => {
                    Launcher.close();
                    Hyprland.dispatch("focuswindow address:" + c.address);
                }
            }))

    results: Providers.rank(root.rows, root.query, (text, q) => Fuzzy.match(text, q))

    onActiveChanged: {
        if (root.active) {
            root.clients = [];
            listProc.running = false;
            listProc.running = true;
        }
    }

    readonly property var listProc: Process {
        id: listProc
        command: [Config.hyprctl, "clients", "-j"]
        stdout: StdioCollector {
            // Same tripwire as Services/KeyboardLayout's hyprctl probe.
            readonly property int maxChars: 1024 * 1024
            onStreamFinished: root.clients = text.length <= maxChars ? Providers.parseClients(text) : []
        }
    }
}
