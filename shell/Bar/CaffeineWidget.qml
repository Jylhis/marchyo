import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Services

// Caffeine (keep-awake) indicator. Mirrors waybar's custom/caffeine: "on" when the
// tagged `marchyo-caffeine-inhibit` systemd-inhibit process is present. Click
// toggles it via the marchyo CLI, then re-probes — no SIGRTMIN dependency (the
// CLI's `pkill -SIGRTMIN+8 waybar` poke is a harmless no-op here).
BarItem {
    id: root

    property bool active: false

    interactive: true
    text: active ? "󰅶" : "󰾪"
    textColor: active ? Color.accent : Color.textMuted
    tooltipText: active ? "Caffeine on — screen stays awake" : "Caffeine off"

    // One-shot probe: running defaults to false and only the timer arms it.
    Process {
        id: probe
        // [m]… so this pgrep's own argv (and every other monitor's caffeine
        // probe) never matches the pattern — only the real
        // `--why=marchyo-caffeine-inhibit` inhibitor does. A bare pattern
        // cross-matches sibling pgreps and flickers the widget on/off.
        command: [Config.pgrep, "-f", "[m]archyo-caffeine-inhibit"]
        onExited: code => root.active = (code === 0)
    }

    // One-shot toggle: armed on click, re-probes when it exits.
    Process {
        id: toggle
        running: false
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
