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

    // Without an object tracker the nodes' audio properties never bind/update.
    readonly property var tracker: PwObjectTracker {
        objects: {
            const list = [];
            if (root.sink)
                list.push(root.sink);
            if (root.source)
                list.push(root.source);
            return list;
        }
    }
}
