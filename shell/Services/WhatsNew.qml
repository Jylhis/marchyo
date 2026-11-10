pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// What changed since the user last looked: the new NEWS entries and a short dix
// summary of the last switch, both from `marchyo whats-new --json`. The panel
// calls refresh() when it opens and markSeen() when it closes.
QtObject {
    id: root

    property var entries: []
    property var summary: []
    property bool loaded: false

    function refresh(): void {
        root.loaded = false;
        root.listProc.running = true;
    }

    function markSeen(): void {
        root.seenProc.running = true;
    }

    readonly property var listProc: Process {
        command: [Config.marchyo, "whats-new", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let report = {};
                try {
                    report = JSON.parse(text);
                } catch (e) {
                    // No answer: show the empty state.
                }
                root.entries = Array.isArray(report.entries) ? report.entries.map(String) : [];
                root.summary = Array.isArray(report.summary) ? report.summary.map(String) : [];
                root.loaded = true;
            }
        }
    }

    readonly property var seenProc: Process {
        command: [Config.marchyo, "whats-new", "--mark-seen"]
    }
}
