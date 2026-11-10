pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Shared screen-recording state. `marchyo capture record` holds the marker
// $XDG_RUNTIME_DIR/marchyo/recording for exactly as long as its recorder runs
// (the wrapper removes it on stop and on a crash), and a FileView doorbell on
// it flips `recording` the moment it appears or goes. A slow pgrep reconcile
// covers a gpu-screen-recorder started outside the CLI and a marker left by a
// killed wrapper. A singleton, so the per-monitor widgets share one watch.
QtObject {
    id: root

    property bool recording: false

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string markerDir: root.runtimeDir === "" ? "" : root.runtimeDir + "/marchyo"
    // Set once the directory exists: the watch only arms on an existing parent.
    property string markerPath: ""

    function toggle() {
        root.toggleProc.running = true;
    }

    readonly property var ensureDir: Process {
        running: root.markerDir !== ""
        command: [Config.mkdir, "-p", "-m", "0700", root.markerDir]
        onExited: {
            root.markerPath = root.markerDir + "/recording";
            root.checkMarker();
        }
    }

    // A doorbell: the watch never reads the marker, it only triggers an
    // existence check.
    readonly property var marker: FileView {
        path: root.markerPath
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: root.checkMarker()
    }

    function checkMarker(): void {
        if (root.markerPath === "")
            return;
        if (root.markerCheck.running)
            root.markerRecheck.restart();
        else
            root.markerCheck.running = true;
    }

    readonly property var markerCheck: Process {
        command: [Config.ls, "-d", root.markerPath]
        onExited: code => root.recording = (code === 0)
    }

    readonly property var markerRecheck: Timer {
        interval: 50
        onTriggered: root.checkMarker()
    }

    // The kernel truncates comm to 15 chars ("gpu-screen-reco"), so `pgrep -x`
    // on the full name never matches; match the full command line with -f.
    readonly property var probe: Process {
        id: probe
        command: [Config.pgrep, "-f", "gpu-screen-recorder"]
        onExited: code => root.recording = (code === 0)
    }

    // A cancelled selection leaves the state unchanged; the marker reports a
    // started or stopped recorder.
    readonly property var toggleProc: Process {
        command: [Config.marchyo, "capture", "record"]
    }

    readonly property var reconcile: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
