pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Shared Pipewire bindings: the default sink/source and their audio objects,
// tracked by one PwObjectTracker. The bar's AudioWidget, the audio panel, and
// the OSD all read these — without the shared tracker each consumer would need
// its own (the audio properties never bind/update otherwise). Same shape as
// SystemStats: a plain qs.Services singleton, the single source of truth.
QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source ? source.audio : null

    // Per-application playback streams (apps producing audio), for the audio
    // panel's per-app volume + live meters. AudioOutStream is a playback stream;
    // AudioInStream (below) is a capture stream.
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

    // Applications currently capturing audio (recording streams). Drives the
    // microphone-in-use privacy indicator.
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

    // Human label for a stream node (the app name, falling back to node fields).
    function streamLabel(n) {
        if (!n)
            return "";
        const p = n.properties || {};
        return p["application.name"] || n.description || n.nickname || n.name || "app";
    }

    // Without an object tracker the nodes' audio properties never bind/update.
    // Track the default sink/source and every app/capture stream so per-app
    // volume and mute stay live in the panel.
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
