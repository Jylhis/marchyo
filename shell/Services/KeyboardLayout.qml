pragma Singleton
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "../Commons/Format.js" as Format

// Shared active-keyboard-layout state (waybar's hyprland/language): ONE startup
// `hyprctl devices -j` probe and ONE Hyprland raw-event listener for the whole
// seat. Layout is a seat property, so a singleton rather than one probe +
// listener per monitor.
QtObject {
    id: root

    // The full keymap name ("English (US)"), as Hyprland reports it.
    property string keymap: ""
    // The short code the bar renders (vs the full keymap above).
    readonly property string code: Format.shortCode(root.keymap)

    function cycle() {
        cycleProc.running = true;
    }

    // Startup probe reads the active keymap once; after that Hyprland's
    // `activelayout` raw event drives updates, so there is no poll.
    readonly property var probe: Process {
        id: probe
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
                    const kb = kbs.find(k => k.main) || kbs[0];
                    root.keymap = (kb && kb.active_keymap) || "";
                } catch (e)
                // Leave the last known layout on a parse hiccup.
                {}
            }
        }
    }

    readonly property var cycleProc: Process {
        id: cycleProc
        command: [Config.hyprctl, "switchxkblayout", "all", "next"]
        // Nothing to re-probe: the raw-event listener below carries the result.
    }

    readonly property var events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            // Payload is "keyboard,layout"; the layout name can itself contain
            // commas ("English (US, intl.)"), so split on the first separator only.
            const sep = event.data.indexOf(",");
            if (sep >= 0)
                root.keymap = event.data.slice(sep + 1).trim();
        }
    }

    Component.onCompleted: probe.running = true
}
