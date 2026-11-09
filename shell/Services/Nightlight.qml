pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared night-light state, owned by the shell: one probe of the hyprsunset
// colour temperature (`hyprctl hyprsunset temperature`) at startup, then
// toggle() and the CLI's `nightlightChanged` IPC call keep it current. Below
// the identity point (6000K) the screen is warmed, i.e. night light is on.
// Actuation goes through `marchyo toggle nightlight on|off` (4000K warm /
// 6500K neutral). A singleton: the widget is a per-monitor view, this state is
// seat-global.
QtObject {
    id: root

    // Warm/neutral threshold; kept in sync with the CLI's 4000K/6500K pair.
    readonly property int identityTemp: 6000
    readonly property int warmTemp: 4000
    readonly property int neutralTemp: 6500
    property int temperature: 6500
    readonly property bool enabled: root.temperature < root.identityTemp

    function toggle() {
        if (toggleProc.running)
            return;
        const next = !root.enabled;
        root.setEnabled(next);
        toggleProc.command = [Config.marchyo, "toggle", "nightlight", next ? "on" : "off"];
        toggleProc.running = true;
    }

    function setEnabled(on: bool): void {
        root.temperature = on ? root.warmTemp : root.neutralTemp;
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
        onExited: code => {
            if (code !== 0)
                root.runProbe();
        }
    }

    Component.onCompleted: root.runProbe()
}
