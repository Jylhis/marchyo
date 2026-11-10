pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons
import "../Commons/Dropbox.js" as DB

// Dropbox daemon state for the Dropbox panel, through the `dropbox` CLI. The
// panel is useful only when that CLI is installed (probe() looks it up on
// PATH); status is polled while the panel is open.
QtObject {
    id: root

    // Unknown until the first probe finishes.
    property bool installed: false
    property bool probed: false
    property string state: "unknown"
    property string detail: ""
    readonly property bool open: PanelManager.openId === "dropbox"

    function probe(): void {
        probeProc.running = true;
    }

    function refresh(): void {
        if (!root.installed || statusProc.running)
            return;
        statusProc.running = true;
    }

    function setRunning(on: bool): void {
        if (!root.installed || actionProc.running)
            return;
        actionProc.command = [Config.bash, "-c", on ? "dropbox start -i" : "dropbox stop"];
        actionProc.running = true;
    }

    onOpenChanged: {
        if (root.open)
            root.probe();
    }

    readonly property var probeProcess: Process {
        id: probeProc
        command: [Config.bash, "-c", "command -v dropbox"]
        onExited: code => {
            root.installed = code === 0;
            root.probed = true;
            root.refresh();
        }
    }

    readonly property var statusProcess: Process {
        id: statusProc
        command: [Config.bash, "-c", "dropbox status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = DB.parseStatus(String(text));
                root.state = s.state;
                root.detail = s.detail;
            }
        }
    }

    readonly property var actionProcess: Process {
        id: actionProc
        onExited: root.refresh()
    }

    readonly property var poll: Timer {
        interval: 5000
        repeat: true
        running: root.open && root.installed
        onTriggered: root.refresh()
    }
}
