pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Paths.js" as Paths
import "../Commons/Workspaces.js" as Ws

// Which block of ten workspace ids each monitor owns
// (marchyo.workspaces.perMonitor), read from the state file
// modules/home/hyprland-monitor-workspaces.lua writes. One watched file for
// every bar, so a singleton.
QtObject {
    id: root

    readonly property bool enabled: Config.perMonitorWorkspaces

    // Connector -> block.
    property var blocks: ({})

    property FileView stateFile: FileView {
        path: Paths.xdgDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), "/.local/state") + "/marchyo/monitors/workspaces"
        watchChanges: root.enabled
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.blocks = Ws.parseBlocks(text())
        onLoadFailed: root.blocks = ({})
    }
}
