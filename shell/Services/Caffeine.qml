pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons

// Shared caffeine (keep-awake) state: ONE 5s `pgrep` probe for the whole seat.
//
// shell.qml builds the bar once per screen (`Variants { model: Quickshell
// .screens }`), so the Timer + Process this used to carry inside CaffeineWidget
// were a poll *per monitor* — a three-monitor host forked three pgreps every
// five seconds to answer one seat-global question. Same reason Audio, Power,
// NetworkStatus and SystemStats are singletons: the widget is a pure view.
QtObject {
    id: root

    property bool active: false

    function toggle() {
        toggleProc.running = true;
    }

    // One-shot probe; `running` starts false and only the poll timer (or a
    // finished toggle) arms it.
    readonly property var probe: Process {
        id: probe
        // The `[m]…` bracket keeps this pgrep's own argv from matching its own
        // pattern — only the real `--why=marchyo-caffeine-inhibit` inhibitor
        // does. A bare pattern self-matches and pins the widget "on".
        command: [Config.pgrep, "-f", "[m]archyo-caffeine-inhibit"]
        onExited: code => root.active = (code === 0)
    }

    // One-shot toggle, armed by toggle(); re-probes when it exits rather than
    // guessing the new state (the CLI's `pkill -SIGRTMIN+8 waybar` poke is a
    // harmless no-op here — the shell has no signal handler).
    readonly property var toggleProc: Process {
        id: toggleProc
        command: [Config.marchyo, "toggle", "caffeine"]
        onExited: probe.running = true
    }

    readonly property var poll: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
