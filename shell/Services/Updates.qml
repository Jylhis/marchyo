pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons
import "../Commons/Health.js" as HealthJs

// Pending-update flag: `marchyo update --check` compares the nixpkgs revision
// pinned in the flake lock with the running system's. The check is local (no
// network), so a slow timer is enough; the first run waits for the session to
// settle.
QtObject {
    id: root

    property bool available: false
    property string locked: ""
    property string runningRev: ""

    readonly property var probe: Process {
        id: probe
        command: [Config.marchyo, "update", "--check", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = HealthJs.parseUpdateCheck(text);
                root.available = r.available;
                root.locked = r.locked;
                root.runningRev = r.running;
            }
        }
    }

    readonly property var first: Timer {
        interval: 60000
        running: true
        onTriggered: probe.running = true
    }

    readonly property var poll: Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: probe.running = true
    }
}
