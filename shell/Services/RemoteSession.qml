pragma Singleton
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "../Commons/Health.js" as HealthJs

// Gliff remote-session detector: is a gliff-server of this user running, and
// from which peer (the ssh client address when it was spawned over ssh). A
// session start shows up as a Hyprland screencast event, so idle costs one
// probe per event plus a slow safety re-check; while a session is active the
// probe repeats every few seconds because its end sends no event.
QtObject {
    id: root

    property bool active: false
    property var peers: []

    function refresh(): void {
        if (!probe.running)
            probe.running = true;
    }

    readonly property string script: "for pid in $(\"$1\" -x -u \"$UID\" gliff-server); do peer=; " + "while IFS= read -r -d '' kv; do case $kv in SSH_CONNECTION=*) peer=${kv#SSH_CONNECTION=}; peer=${peer%% *};; esac; " + "done 2>/dev/null < \"/proc/$pid/environ\"; printf '%s %s\\n' \"$pid\" \"$peer\"; done"

    readonly property var probe: Process {
        id: probe
        command: [Config.bash, "-c", root.script, "bash", Config.pgrep]
        stdout: StdioCollector {
            onStreamFinished: {
                const state = HealthJs.parseRemoteProbe(text);
                root.active = state.active;
                root.peers = state.peers;
            }
        }
    }

    readonly property var events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name === "screencast")
                debounce.restart();
        }
    }

    readonly property var debounce: Timer {
        interval: 200
        onTriggered: root.refresh()
    }

    readonly property var poll: Timer {
        interval: root.active ? 5000 : 120000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
