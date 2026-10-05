pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell.Services.Pipewire

// Shared Pipewire bindings for AudioWidget, the audio panel, and the OSD. One
// PwObjectTracker keeps every tracked node live: the audio properties never
// bind/update without a tracker.
//
// Two traps are pinned by the design below, both shipped as the flickering
// audio panel:
//
// 1. Node-type checks are EQUALITY, never bitmask. PwNodeType's values are
//    dense enum constants, not flags (AudioOutStream 21 = 0b10101,
//    AudioInStream 13 = 0b01101; 13 & 21 = 5), so `type & AudioOutStream`
//    also matched every input stream. Each PwNodePeakMonitor row creates a
//    "Quickshell Peak Detect" capture tap (Stream/Input/Audio); with the
//    bitmask check each tap entered the out-stream list, spawned another
//    row+monitor, whose tap entered again: a self-amplifying storm that
//    reset the panel's Repeaters continuously (flicker, buttons destroyed
//    mid-click, Pipewire "-116 no global" bursts from monitors resubscribing
//    to torn-down taps).
//
// 2. The stream lists are recomputed imperatively from the nodes model's
//    values/insert/remove signals — never as a binding over
//    Pipewire.nodes.values. A binding re-evaluates on EVERY node property
//    change and hands the Repeaters a fresh array identity each time (JS
//    arrays cannot be diffed), fully resetting them. The membership guard
//    below keeps the assigned arrays stable through peak traffic.
//
// Membership filters read only properties available on unbound nodes
// (isStream, isSink, type), never tracker-bound ones like n.audio or
// n.properties, which materialize only while a node is bound and would feed
// the churn from the other side. The one exception is telling this shell's own
// PwNodePeakMonitor taps apart from real capture streams: both are
// AudioInStream nodes and only the bound `properties` say which is which. So
// every input stream is a tracked *candidate* (membership by type alone), and
// captureStreams is classified from the candidates' properties, re-run when
// a candidate's properties arrive. Tracking a candidate never depends on its
// classification, so there is no bind/unbind loop.
QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source ? source.audio : null

    // Selectable output devices for the panel's sink picker.
    property var sinks: []

    // Per-app playback streams for the panel's per-app volume + meters.
    property var appStreams: []

    // Every input stream, real or a peak tap (tracked so its properties bind).
    property var inCandidates: []

    // Apps capturing audio; drives the microphone-in-use privacy indicator.
    property var captureStreams: []

    readonly property bool micInUse: captureStreams.length > 0

    function collectStreams(want): var {
        const out = [];
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.isStream && n.type === want)
                out.push(n);
        }
        return out;
    }

    // A candidate is a real capture once its bound properties are in and it
    // is not one of this shell's PwNodePeakMonitor taps ("Quickshell Peak
    // Detect"): meters running must never read as a hot microphone. Until the
    // properties arrive (a few ms after the tracker binds it) it is not counted.
    function classifyCapture(): void {
        const c = [];
        for (let i = 0; i < root.inCandidates.length; i++) {
            const n = root.inCandidates[i];
            const p = n ? n.properties : null;
            if (!p || Object.keys(p).length === 0)
                continue;
            if (p["application.name"] === "Quickshell Peak Detect")
                continue;
            c.push(n);
        }
        if (!root.sameMembers(root.captureStreams, c))
            root.captureStreams = c;
    }

    function collectSinks(): var {
        const out = [];
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.isSink && !n.isStream)
                out.push(n);
        }
        return out;
    }

    // Same membership check (same objects, same order) as a cheap change
    // guard: assigning an equal array to a var property still emits, so the
    // comparison decides whether to assign at all.
    function sameMembers(a, b): bool {
        if (!a || a.length !== b.length)
            return false;
        for (let i = 0; i < b.length; i++) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function refresh(): void {
        const s = root.collectSinks();
        if (!root.sameMembers(root.sinks, s))
            root.sinks = s;
        const o = root.collectStreams(PwNodeType.AudioOutStream);
        if (!root.sameMembers(root.appStreams, o))
            root.appStreams = o;
        const c = root.collectStreams(PwNodeType.AudioInStream);
        if (!root.sameMembers(root.inCandidates, c))
            root.inCandidates = c;
        root.classifyCapture();
    }

    // One properties watcher per input-stream candidate. The model only
    // changes with candidate membership, never with property traffic.
    readonly property var candidateWatch: Instantiator {
        model: root.inCandidates
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPropertiesChanged(): void {
                root.classifyCapture();
            }
        }
    }

    Component.onCompleted: root.refresh()

    // The nodes model signal that can change set membership (ObjectModel
    // rebuilds its values on inserts and removes alike, so one handler
    // covers both). dataChanged (peak/volume updates) is deliberately not
    // followed: it cannot add or remove a node, and reacting to it is
    // exactly the churn this layout exists to prevent.
    readonly property var nodesConn: Connections {
        target: Pipewire.nodes
        function onValuesChanged(): void {
            root.refresh();
        }
    }

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
            return list.concat(root.appStreams).concat(root.inCandidates);
        }
    }
}
