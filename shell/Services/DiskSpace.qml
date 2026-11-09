pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons
import "../Commons/Health.js" as HealthJs

// Free space of the filesystem holding the Nix store. The threshold is
// marchyo.shell.diskWarnPercent, delivered through shell.json's
// health.diskWarnPercent (default 10).
QtObject {
    id: root

    property var df: null
    readonly property int warnPercent: {
        const h = ShellConfig.config.health;
        return h && typeof h.diskWarnPercent === "number" ? h.diskWarnPercent : 10;
    }
    readonly property bool low: HealthJs.diskLow(root.df, root.warnPercent)
    readonly property int freePercent: root.df ? root.df.freePercent : 100
    readonly property string freeText: root.df ? HealthJs.formatKb(root.df.availKb) : ""

    readonly property var probe: Process {
        id: probe
        command: [Config.df, "-kP", "/nix"]
        stdout: StdioCollector {
            onStreamFinished: root.df = HealthJs.parseDf(text)
        }
    }

    readonly property var poll: Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
