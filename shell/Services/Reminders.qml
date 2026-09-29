pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared reminder state: ONE poll of the pending `marchyo reminder` timers for
// the whole seat.
//
// The marchyo CLI schedules reminders as transient systemd user timers named
// `marchyo-reminder-*` (commands/utilities.ts). Counting the live timers is the
// same source of truth `marchyo reminder show` reads, so the bar and CLI never
// disagree. Singleton for the usual reason: the widget is a pure per-monitor
// view and this count is seat-global.
QtObject {
    id: root

    property int count: 0

    // `systemctl --user list-timers --no-legend <glob>` prints one line per
    // matching timer (and nothing when none match), so the non-empty line count
    // is the pending-reminder count. --all keeps timers that have not armed yet.
    readonly property var probe: Process {
        id: probe
        command: [Config.systemctl, "--user", "list-timers", "--all", "--no-legend", "marchyo-reminder-*"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text).split("\n").filter(l => l.trim() !== "");
                root.count = lines.length;
            }
        }
        onExited: code => {
            if (code !== 0)
                root.count = 0;
        }
    }

    // Reminders fire on the order of minutes; a 30s poll keeps the badge fresh
    // without waking the CPU often.
    readonly property var poll: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
