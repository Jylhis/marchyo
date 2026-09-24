pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Shared MPRIS bindings: the one "active" media player for the seat, plus the
// resolved track metadata and playback controls the bar's MediaWidget reads.
// Like Audio/Power/NetworkStatus this is a plain qs.Services singleton — the
// widget is instantiated once per monitor, so the player lookup lives here once
// rather than re-deriving on every bar. Native Quickshell.Services.Mpris auto-
// discovers every org.mpris.MediaPlayer2* on the bus; no external tool.
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

    // Nudge `rev` when the set of players changes so `player` re-picks. The
    // per-player isPlayingChanged is harder to wire without a Repeater, so we
    // also re-pick when the current player stops (covered by playbackState below).
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
