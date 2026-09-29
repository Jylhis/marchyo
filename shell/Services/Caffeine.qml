pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared caffeine (keep-awake) state: ONE 5s pgrep probe for the whole seat.
// A singleton (not per-widget) because the bar is built once per screen, so a
// Timer + Process in the widget would poll once per monitor for one seat-global
// answer.
QtObject {
    id: root

    property bool active: false

    function toggle() {
        toggleProc.running = true;
    }

    readonly property var probe: Process {
        id: probe
        // The [m] bracket stops this pgrep's own argv from matching its pattern
        // (a bare pattern self-matches and pins the widget "on"); only the real
        // --why=marchyo-caffeine-inhibit inhibitor matches.
        command: [Config.pgrep, "-f", "[m]archyo-caffeine-inhibit"]
        onExited: code => root.active = (code === 0)
    }

    // Re-probes on exit rather than guessing the new state.
    readonly property var toggleProc: Process {
        id: toggleProc
        command: [Config.marchyo, "toggle", "caffeine"]
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
