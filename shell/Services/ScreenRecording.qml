pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared screen-recording state: ONE 5s `pgrep` probe for the whole seat.
//
// shell.qml builds the bar once per screen (`Variants { model: Quickshell
// .screens }`), so a Timer + Process inside the widget would poll once per
// monitor — a three-monitor host would fork three pgreps every five seconds to
// answer one seat-global question. Same reasoning as Caffeine: the widget is a
// pure view and the probe/toggle live here.
QtObject {
    id: root

    property bool recording: false

    function toggle() {
        toggleProc.running = true;
    }

    // One-shot probe. The kernel truncates comm to 15 chars
    // ("gpu-screen-reco"), so `pgrep -x` on the full name never matches — the
    // marchyo CLI's `capture record` matches the full command line the same
    // way (commands/capture.ts).
    readonly property var probe: Process {
        id: probe
        command: [Config.pgrep, "-f", "gpu-screen-recorder"]
        onExited: code => root.recording = (code === 0)
    }

    // `marchyo capture record` toggles: if a recording is running it stops and
    // finalizes the mp4, otherwise it slurp-selects a region and starts one.
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
