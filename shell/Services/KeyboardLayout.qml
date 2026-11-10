pragma Singleton
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "../Commons/Format.js" as Format
import "../Commons/KeyboardLayoutModel.js" as Model

// Layout is seat-global, so probes and events are shared by every monitor.
QtObject {
    id: root

    // The full keymap name ("English (US)"), as Hyprland reports it.
    property string keymap: ""
    property bool multiple: false
    property string eventKeyboard: ""
    property bool pendingProbe: false
    // The short code the bar renders (vs the full keymap above).
    readonly property string code: Format.shortCode(root.keymap)

    function cycle() {
        root.cycleProc.running = true;
    }

    function refresh() {
        if (root.probe.running)
            root.pendingProbe = true;
        else
            root.probe.running = true;
    }

    readonly property Timer retry: Timer {
        interval: 10000
        repeat: true
        running: root.keymap.length === 0
        onTriggered: root.refresh()
    }

    readonly property var probe: Process {
        command: [Config.hyprctl, "devices", "-j"]
        stdout: StdioCollector {
            // A tripwire, not a memory cap (the stream is already buffered): refuse
            // to parse and retain an answer no healthy `hyprctl devices` could
            // produce, in a session-long process. Counted in UTF-16 units.
            readonly property int maxChars: 1024 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return; // Keep the last known layout rather than parsing it.
                try {
                    const kbs = JSON.parse(text).keyboards || [];
                    const kb = Model.selectKeyboard(kbs, root.eventKeyboard);
                    root.keymap = (kb && kb.active_keymap) || "";
                    root.multiple = Model.hasMultipleLayouts(kb);
                } catch (e)
                // Leave the last known layout on a parse hiccup.
                {}
            }
        }
        onExited: {
            if (root.pendingProbe) {
                root.pendingProbe = false;
                root.refresh();
            }
        }
    }

    readonly property var cycleProc: Process {
        command: [Config.hyprctl, "switchxkblayout", "all", "next"]
        onExited: root.refresh()
    }

    readonly property var events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.refresh();
                return;
            }
            if (event.name !== "activelayout")
                return;
            const name = Model.eventKeyboard(event.data);
            if (!name)
                return;
            root.eventKeyboard = name;
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
