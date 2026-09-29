pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Shared Pipewire bindings for AudioWidget, the audio panel, and the OSD. One
// PwObjectTracker keeps every tracked node live: the audio properties never
// bind/update without a tracker.
QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source ? source.audio : null

    // Per-app playback streams for the panel's per-app volume + meters.
    readonly property var appStreams: {
        const out = [];
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.isStream && n.audio && (n.type & PwNodeType.AudioOutStream))
                out.push(n);
        }
        return out;
    }

    // Apps capturing audio; drives the microphone-in-use privacy indicator.
    readonly property var captureStreams: {
        const out = [];
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.isStream && (n.type & PwNodeType.AudioInStream))
                out.push(n);
        }
        return out;
    }

    readonly property bool micInUse: captureStreams.length > 0

    function streamLabel(n) {
        if (!n)
            return "";
        const p = n.properties || {};
        return p["application.name"] || n.description || n.nickname || n.name || "app";
    }

    readonly property var tracker: PwObjectTracker {
        objects: {
            const list = [];
            if (root.sink)
                list.push(root.sink);
            if (root.source)
                list.push(root.source);
            return list.concat(root.appStreams).concat(root.captureStreams);
        }
    }
}
