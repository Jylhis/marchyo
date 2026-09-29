pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Shared MPRIS bindings: the one "active" media player for the seat plus its
// resolved metadata and controls, for MediaWidget. A singleton so the player
// lookup runs once, not once per monitor. Native Quickshell.Services.Mpris
// auto-discovers every org.mpris.MediaPlayer2* on the bus.
QtObject {
    id: root

    // The active player: prefer one that is currently playing, else the first
    // controllable player, else null. Recomputed whenever the player list or any
    // player's playback state changes (the Connections below poke `rev`).
    property int rev: 0
    readonly property var player: {
        rev; // re-evaluate on model/state changes
        const list = Mpris.players ? Mpris.players.values : [];
        if (list.length === 0)
            return null;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying)
                return list[i];
        }
        return list[0];
    }

    readonly property bool active: player !== null
    readonly property bool isPlaying: active && player.isPlaying
    readonly property string title: active ? (player.trackTitle || "") : ""
    readonly property string artist: active ? (player.trackArtist || "") : ""
    readonly property bool canGoNext: active && player.canGoNext
    readonly property bool canGoPrevious: active && player.canGoPrevious
    readonly property bool canTogglePlaying: active && player.canTogglePlaying

    function playPause() {
        if (active && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (active && player.canGoNext)
            player.next();
    }

    function previous() {
        if (active && player.canGoPrevious)
            player.previous();
    }

    // Nudge `rev` so `player` re-picks when the player set changes; stateConn
    // below does the same when the current player's playback state changes.
    readonly property var conn: Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.rev++;
        }
    }

    readonly property var stateConn: Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPlaybackStateChanged() {
            root.rev++;
        }
    }
}
