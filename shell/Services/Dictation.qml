pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Shared dictation state for the seat, whatever the backend
// (Style.dictationBackend, baked from marchyo.dictation.backend).
//
// voxtype: ONE `voxtype status --follow` subscription, event-driven. A
// singleton so a per-monitor Process does not open one subscription per screen
// against the same daemon. `running` on a long-lived stream is a one-shot: when
// voxtype exits nothing reopens it, so the backoff below restarts it while
// keeping a permanently-failing command from becoming a spawn loop.
//
// superwhisper and hex have no status stream, so `marchyo dictation status` is
// read on a slow bounded timer, and once right after a toggle from the bar.
QtObject {
    id: root

    // idle / recording / transcribing (stopped maps to idle).
    property string state: "idle"
    // Empty until the first status line; the widget supplies a fallback glyph.
    property string glyph: ""

    // True while the backend answers: between the first parseable status line of
    // a voxtype run and its end, or while the last poll found the backend up.
    // Shown in the tooltip, not by recolouring the glyph (colour already means
    // "recording").
    property bool streaming: false

    readonly property string backend: Style.dictationBackend
    readonly property bool followsStream: backend === "voxtype"

    // Only read state when the indicator is actually baked in (marchyo.dictation
    // .indicator -> Style.dictationIndicator); a host without it has no reader.
    readonly property bool wanted: Style.dictationIndicator

    // Restart backoff in ms: doubled on each end, reset by the first parsed line,
    // capped so a broken voxtype costs one spawn a minute, not a spawn loop.
    readonly property int retryMin: 1000
    readonly property int retryMax: 60000
    property int retryDelay: retryMin

    readonly property int pollMs: 2000

    function toggle() {
        Quickshell.execDetached([Config.marchyo, "dictation", "toggle"]);
        if (!root.followsStream && root.wanted)
            settle.restart();
    }

    function applyPoll(text) {
        let obj = null;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            root.streaming = false;
            return;
        }
        const s = obj && obj.dictation ? obj.dictation.state : "";
        root.streaming = s !== "" && s !== "stopped" && s !== "unknown";
        root.state = (s === "recording" || s === "transcribing") ? s : "idle";
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

    readonly property var poll: Process {
        id: poll
        command: [Config.marchyo, "dictation", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.applyPoll(text)
        }
    }

    readonly property var pollTimer: Timer {
        interval: root.pollMs
        repeat: true
        running: root.wanted && !root.followsStream
        triggeredOnStart: true
        onTriggered: if (!poll.running)
            poll.running = true
    }

    // A toggle from the bar changes the state after the CLI returns: read it
    // again once instead of waiting out the poll interval.
    readonly property var settle: Timer {
        id: settle
        interval: 400
        repeat: false
        onTriggered: if (!poll.running)
            poll.running = true
    }

    Component.onCompleted: if (root.wanted && root.followsStream)
        stream.running = true
}
