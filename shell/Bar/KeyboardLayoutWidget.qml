import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Active keyboard layout, mirroring waybar's hyprland/language "{short}". Reads the
// main keyboard's active_keymap from `hyprctl devices -j` and renders a short code;
// click cycles layouts (a no-op on single-layout hosts). Hidden until a layout is
// known so it never shows a stray placeholder.
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

    visible: layout.length > 0
    interactive: true
    text: layout
    textColor: Color.textMuted

    function shortCode(keymap) {
        if (!keymap)
            return "";
        if (shortMap[keymap] !== undefined)
            return shortMap[keymap];
        return keymap.split(/[ (]/)[0].toLowerCase().slice(0, 3);
    }

    Process {
        id: probe
        command: [Config.hyprctl, "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards || [];
                    let kb = kbs.find(k => k.main) || kbs[0];
                    root.layout = root.shortCode(kb ? kb.active_keymap : "");
                } catch (e) {
                    // Leave the last known layout on a parse hiccup.
                }
            }
        }
    }

    Process {
        id: cycle
        command: [Config.hyprctl, "switchxkblayout", "all", "next"]
        onExited: probe.running = true
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    onClicked: cycle.running = true
}
