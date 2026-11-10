pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons

// Hyprland's animations:enabled option for Style.duration(), probed once and
// again on every config reload. The `marchyo toggle reduce-motion` override
// comes from Services/RuntimeStyle. One probe for every surface, so a
// singleton; start() is called once from shell.qml.
QtObject {
    id: root

    property bool animationsEnabled: true

    readonly property bool reduced: RuntimeStyle.reduceMotion || !root.animationsEnabled

    onAnimationsEnabledChanged: Style.compositorAnimationsOff = !root.animationsEnabled

    function start(): void {
        root.probe();
    }

    function probe(): void {
        if (!probeProc.running)
            probeProc.running = true;
    }

    // `hyprctl -j getoption animations:enabled` prints {"option":..., "int": 0|1, ...}.
    // A failed probe (no Hyprland) leaves animations enabled.
    readonly property var probeProc: Process {
        command: [Config.hyprctl, "-j", "getoption", "animations:enabled"]
        stdout: StdioCollector {
            readonly property int maxChars: 4096
            onStreamFinished: {
                if (text.length > maxChars)
                    return;
                try {
                    const v = JSON.parse(text);
                    const on = v.int !== undefined ? v.int : v.bool;
                    if (on !== undefined)
                        root.animationsEnabled = on === true || on > 0;
                } catch (e) {
                    root.animationsEnabled = true;
                }
            }
        }
    }

    readonly property var events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.probe();
        }
    }
}
