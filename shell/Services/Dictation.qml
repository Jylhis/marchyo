pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Shared dictation (voxtype) state: ONE `voxtype status --follow` subscription
// for the whole seat. A singleton so a per-monitor Process does not open one
// subscription per screen against the same daemon.
//
// `running` on a long-lived stream is a one-shot: when voxtype exits (restart,
// crash, binary swap) nothing reopens it, so the backoff below restarts it while
// keeping a permanently-failing command from becoming a spawn loop.
QtObject {
    id: root

    // voxtype's status `class`: idle / recording / transcribing.
    property string state: "idle"
    // Empty until the first status line; the widget supplies a fallback glyph.
    property string glyph: ""

    // True between the first parseable status line of a run and its end. Shown in
    // the tooltip, not by recolouring the glyph (colour already means "recording").
    property bool streaming: false

    // Only subscribe when the indicator is actually baked in (marchyo.dictation
    // .indicator -> Style.dictationIndicator); a host without it has no reader.
    readonly property bool wanted: Style.dictationIndicator

    // Restart backoff in ms: doubled on each end, reset by the first parsed line,
    // capped so a broken voxtype costs one spawn a minute, not a spawn loop.
    readonly property int retryMin: 1000
    readonly property int retryMax: 60000
    property int retryDelay: retryMin

    function toggle() {
        Quickshell.execDetached([Config.voxtype, "record", "toggle"]);
    }

    readonly property var stream: Process {
        id: stream
        command: [Config.voxtype, "status", "--format", "json", "--follow", "--icon-theme", "nerd-font"]
        stdout: SplitParser {
            onRead: line => {
                let obj = null;
                try {
                    obj = JSON.parse(line);
                } catch (e) {
                    return; // A non-JSON banner line is not a stream failure.
                }
                // A parsed line proves the run is healthy: reset the backoff.
                root.retryDelay = root.retryMin;
                root.streaming = true;
                if (obj.class)
                    root.state = obj.class;
                if (obj.text)
                    root.glyph = obj.text;
            }
        }
        // Handles both an exited stream and a start that never happened: a
        // command that cannot start emits no `exited`, only drops `running`.
        onRunningChanged: {
            if (running || !root.wanted)
                return;
            root.streaming = false;
            retry.restart();
        }
    }

    readonly property var retry: Timer {
        id: retry
        interval: root.retryDelay
        repeat: false
        onTriggered: {
            root.retryDelay = Math.min(root.retryMax, root.retryDelay * 2);
            stream.running = true;
        }
    }

    Component.onCompleted: if (root.wanted)
        stream.running = true
}
