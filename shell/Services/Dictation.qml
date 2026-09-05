pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Shared dictation (voxtype) state: ONE `voxtype status --follow` subscription
// for the whole seat, plus a restart for when it ends.
//
// Both halves fix real defects the widget had while it owned the Process:
//
//  - shell.qml builds the bar (and every widget in it) once per screen through
//    `Variants { model: Quickshell.screens }`, so a Process declared in a widget
//    is a Process *per monitor* — a two-monitor host ran two long-lived voxtype
//    subscriptions against the same daemon. Seat-global work belongs in a
//    singleton (the shape Audio/Power/NetworkStatus/SystemStats already use) and
//    the widget becomes a pure view.
//  - `running: <flag>` on a long-lived stream is a one-shot. When voxtype exits
//    — daemon restart, crash, a `nixos-rebuild switch` swapping the binary — the
//    stream closes and nothing ever reopens it, so the widget froze on its last
//    state for the rest of the session. The backoff below reopens it while
//    keeping a permanently-failing command (voxtype absent, or exiting at once)
//    from becoming a spawn loop inside the long-running shell process.
QtObject {
    id: root

    // voxtype's status `class`: idle / recording / transcribing.
    property string state: "idle"
    // The nerd-font glyph voxtype emits under --icon-theme nerd-font. Empty
    // until the first status line arrives; the widget supplies a fallback.
    property string glyph: ""

    // True while a run has produced at least one parseable status line and has
    // not since ended. The widget reports this in its tooltip rather than by
    // recolouring the glyph: the colour channel already means "recording", so
    // spending it on "the stream is down" would make one state read as another.
    property bool streaming: false

    // Only subscribe when the indicator is actually baked in (marchyo.dictation
    // .indicator -> Style.dictationIndicator); a host without it has no reader.
    readonly property bool wanted: Style.dictationIndicator

    // Restart backoff in ms: doubled every time the stream ends, reset by the
    // first parsed line of a healthy run, capped so a broken voxtype costs one
    // spawn a minute instead of a spawn loop.
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
                // A parsed line proves this run is healthy, so drop back to the
                // shortest retry: otherwise one slow restart would leave a long
                // delay armed against the next genuine failure.
                root.retryDelay = root.retryMin;
                root.streaming = true;
                if (obj.class)
                    root.state = obj.class;
                if (obj.text)
                    root.glyph = obj.text;
            }
        }
        // Covers an exited stream and a start that never happened alike:
        // Quickshell drops `running` in both cases, and a command that cannot
        // start emits no `exited` at all.
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
