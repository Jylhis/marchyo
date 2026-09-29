pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared screen-recording state: ONE 5s pgrep probe for the whole seat. A
// singleton (like Caffeine) so a Timer + Process in the widget does not poll
// once per monitor for one seat-global answer.
QtObject {
    id: root

    property bool recording: false

    function toggle() {
        toggleProc.running = true;
    }

    // The kernel truncates comm to 15 chars ("gpu-screen-reco"), so `pgrep -x`
    // on the full name never matches; match the full command line with -f.
    readonly property var probe: Process {
        id: probe
        command: [Config.pgrep, "-f", "gpu-screen-recorder"]
        onExited: code => root.recording = (code === 0)
    }

    // Re-probe on exit rather than guessing (a cancelled selection leaves the
    // state unchanged).
    readonly property var toggleProc: Process {
        id: toggleProc
        command: [Config.marchyo, "capture", "record"]
        onExited: probe.running = true
    }

    readonly property var poll: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
