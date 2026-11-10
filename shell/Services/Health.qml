pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons
import "../Commons/Health.js" as HealthJs

// Session health from `marchyo doctor --json`: the failing and warning checks.
// Doctor exits 1 when a check fails, so only the JSON on stdout is read. The
// run spawns a few probes, so it repeats on a long timer.
QtObject {
    id: root

    property var failed: []
    property var warned: []

    readonly property var probe: Process {
        id: probe
        command: [Config.marchyo, "doctor", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = HealthJs.parseDoctor(text);
                root.failed = r.failed;
                root.warned = r.warned;
            }
        }
    }

    readonly property var first: Timer {
        interval: 45000
        running: true
        onTriggered: probe.running = true
    }

    readonly property var poll: Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: probe.running = true
    }
}
