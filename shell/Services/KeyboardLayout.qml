pragma Singleton
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "../Commons/Format.js" as Format

// Shared active-keyboard-layout state, mirroring waybar's hyprland/language:
// ONE startup `hyprctl devices -j` probe and ONE Hyprland raw-event listener
// for the whole seat.
//
// shell.qml builds the bar once per screen (`Variants { model: Quickshell
// .screens }`), so the probe and the event subscription used to be duplicated
// per monitor — N `hyprctl` forks at startup and N handlers doing identical
// work on every `activelayout` event. The layout is a seat property, not a
// screen property, so it lives in a singleton and the widget is a pure view.
QtObject {
    id: root

    // The full keymap name ("English (US)"), as Hyprland reports it.
    property string keymap: ""
    // waybar's "{short}": the short code the bar renders.
    readonly property string code: Format.shortCode(root.keymap)

    function cycle() {
        cycleProc.running = true;
    }

    // Startup probe: read the main keyboard's active keymap once. Everything
    // after that is event-driven — Hyprland emits `activelayout` whenever
    // switchxkblayout (or anything else) changes it, so there is no poll.
    readonly property var probe: Process {
        id: probe
        command: [Config.hyprctl, "devices", "-j"]
        stdout: StdioCollector {
            // A tripwire, not a limit: StdioCollector has already buffered the
            // stream by the time this runs, so this cannot cap peak memory. It
            // refuses to *parse and retain* an answer no healthy `hyprctl
            // devices` could have produced, inside a process that lives for the
            // whole session. Counted in UTF-16 units — QML strings have no byte
            // view — against a device list that is realistically a few KiB.
            readonly property int maxChars: 1024 * 1024
            onStreamFinished: {
                if (text.length > maxChars)
                    return; // Keep the last known layout rather than parsing it.
                try {
                    const kbs = JSON.parse(text).keyboards || [];
                    const kb = kbs.find(k => k.main) || kbs[0];
                    root.keymap = (kb && kb.active_keymap) || "";
                } catch (e)
                // Leave the last known layout on a parse hiccup: a half-read or
                // malformed document means "no news", never a wrong answer.
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
            // Payload is "keyboard,layout"; the layout name itself can contain
            // commas ("English (US, intl.)"), so everything after the first
            // separator is the keymap.
            const sep = event.data.indexOf(",");
            if (sep >= 0)
                root.keymap = event.data.slice(sep + 1).trim();
        }
    }

    Component.onCompleted: probe.running = true
}
