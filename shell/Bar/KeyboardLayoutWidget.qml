import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import qs.Commons

// Active keyboard layout, mirroring waybar's hyprland/language "{short}". One
// initial `hyprctl devices -j` probe at startup, then Hyprland's raw event
// stream drives every change (the `activelayout` event carries
// "keyboard, layout") — no poll timer, matching the bar's event-driven
// philosophy. Click cycles layouts (a no-op on single-layout hosts). Hidden
// until a layout is known so it never shows a stray placeholder.
BarItem {
    id: root

    // Common full keymap names → short codes; fall back to the first word lowercased.
    readonly property var shortMap: ({
            "English (US)": "us",
            "English (UK)": "gb",
            "Finnish": "fi",
            "Swedish": "se",
            "German": "de",
            "French": "fr",
            "Norwegian": "no"
        })
    property string layout: ""
    // The full keymap name, kept for the tooltip (waybar's tooltip-format "{long}").
    property string layoutLong: ""

    visible: layout.length > 0
    interactive: true
    text: layout
    textColor: Color.textMuted
    tooltipText: layoutLong

    function shortCode(keymap) {
        if (!keymap)
            return "";
        if (shortMap[keymap] !== undefined)
            return shortMap[keymap];
        return keymap.split(/[ (]/)[0].toLowerCase().slice(0, 3);
    }

    function applyKeymap(keymap) {
        root.layoutLong = keymap || "";
        root.layout = root.shortCode(keymap);
    }

    // Startup probe: read the main keyboard's active keymap once.
    Process {
        id: probe
        running: false
        command: [Config.hyprctl, "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards || [];
                    const kb = kbs.find(k => k.main) || kbs[0];
                    root.applyKeymap(kb ? kb.active_keymap : "");
                } catch (e) {
                    // Leave the last known layout on a parse hiccup.
                }
            }
        }
    }

    Component.onCompleted: probe.running = true

    // Then react to layout changes: Hyprland emits `activelayout` with
    // "keyboard, layout" whenever switchxkblayout (or anything else) changes it.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.data.split(",");
                if (parts.length >= 2)
                    root.applyKeymap(parts[1].trim());
            }
        }
    }

    Process {
        id: cycle
        running: false
        command: [Config.hyprctl, "switchxkblayout", "all", "next"]
        onExited: {
            // The raw-event listener updates the label; nothing to re-probe.
        }
    }

    onClicked: cycle.running = true
}
