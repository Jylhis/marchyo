pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared night-light state: ONE seat-wide probe of the hyprsunset colour
// temperature (`hyprctl hyprsunset temperature`). Below the identity point
// (6000K) the screen is warmed, i.e. night light is on. Actuation goes through
// `marchyo toggle nightlight` (4000K warm / 6500K neutral) so shell, keybinds,
// and CLI share one source of truth. A singleton: the widget is a per-monitor
// view, this state is seat-global.
QtObject {
    id: root

    // Warm/neutral threshold; kept in sync with the CLI's 4000K/6500K pair.
    readonly property int identityTemp: 6000
    property int temperature: 6500
    readonly property bool enabled: root.temperature < root.identityTemp

    function toggle() {
        toggleProc.running = true;
    }

    // Live temperature probe. `hyprctl hyprsunset temperature` prints a number
    // (with surrounding text on some versions); take the first integer run.
    // When hyprsunset is not running hyprctl exits non-zero with an error that
    // contains digits (the socket path), so only a zero exit is parsed and any
    // failure reads as neutral. stdout and the exit can arrive in either order;
    // both feed applyProbe().
    property int probeExit: -1
    property string probeText: ""

    function applyProbe(): void {
        if (root.probeExit > 0) {
            root.temperature = 6500;
            return;
        }
        if (root.probeExit !== 0)
            return;
        const m = root.probeText.match(/[0-9]+/);
        if (m)
            root.temperature = parseInt(m[0]);
    }

    readonly property var probe: Process {
        id: probe
        command: [Config.hyprctl, "hyprsunset", "temperature"]
        stdout: StdioCollector {
            readonly property int maxChars: 4096
            onStreamFinished: {
                root.probeText = text.length <= maxChars ? String(text) : "";
                root.applyProbe();
            }
        }
        onExited: code => {
            root.probeExit = code;
            root.applyProbe();
        }
    }

    function runProbe(): void {
        root.probeExit = -1;
        probe.running = true;
    }

    // `marchyo toggle nightlight` flips 4000K <-> 6500K. Re-probe on exit so the
    // indicator reflects the daemon, not a guess.
    readonly property var toggleProc: Process {
        id: toggleProc
        command: [Config.marchyo, "toggle", "nightlight"]
        onExited: root.runProbe()
    }

    readonly property var poll: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.runProbe()
    }
}
