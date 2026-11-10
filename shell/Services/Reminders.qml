pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/ReminderFlow.js" as Flow

// Shared reminder state: ONE seat-wide poll of the pending `marchyo reminder`
// timers. The CLI schedules them as transient systemd user timers named
// `marchyo-reminder-*`, so counting live timers is the same source of truth
// `marchyo reminder show` reads. A singleton; the count is seat-global.
QtObject {
    id: root

    property int count: 0

    function invalidMinutes(): void {
        const title = I18n.t("reminders.title");
        const message = I18n.t("reminders.invalidMinutes");
        Quickshell.execDetached([Config.marchyo, "notify", title, message]);
    }

    function schedule(minutes: real, message: string): bool {
        if (scheduleProc.running || Flow.minutes(String(minutes)) === 0)
            return false;
        const fallback = I18n.t("reminders.title");
        scheduleProc.command = Flow.scheduleArgs(Config.marchyo, minutes, message, fallback);
        scheduleProc.running = true;
        return true;
    }

    readonly property var scheduleProcess: Process {
        id: scheduleProc
        onExited: probe.running = true
    }

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
