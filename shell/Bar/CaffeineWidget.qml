import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// Caffeine (keep-awake) indicator. Mirrors waybar's custom/caffeine: "on" when the
// tagged `marchyo-caffeine-inhibit` systemd-inhibit process is present. Click
// toggles it via the marchyo CLI, then re-probes — no SIGRTMIN dependency (the
// CLI's `pkill -SIGRTMIN+8 waybar` poke is a harmless no-op here).
BarItem {
    id: root

    property bool active: false

    interactive: true
    text: active ? "calf on" : "calf"
    textColor: active ? Color.accent : Color.textMuted

    // Exit code 0 = a matching process exists, so caffeine is on.
    Process {
        id: probe
        command: [Config.pgrep, "-f", "marchyo-caffeine-inhibit"]
        onExited: code => root.active = (code === 0)
    }

    Process {
        id: toggle
        command: [Config.marchyo, "toggle", "caffeine"]
        onExited: probe.running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    onClicked: toggle.running = true
}
