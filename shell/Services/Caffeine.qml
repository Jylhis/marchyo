pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons

// Shared caffeine (keep-awake) state: ONE 5s pgrep probe for the whole seat.
// A singleton (not per-widget) because the bar is built once per screen, so a
// Timer + Process in the widget would poll once per monitor for one seat-global
// answer.
//
// Two independent inhibit sources:
// - manual: `marchyo toggle caffeine` (stops hypridle and holds a tagged
//   sleep:idle inhibitor). Only toggle() and the CLI change it.
// - auto (video): while an MPRIS player that looks like video is Playing, the
//   shell holds its own `systemd-inhibit --what=idle` under a distinct tag.
//   hypridle honours logind idle inhibitors (ignore_systemd_inhibit defaults to
//   false), so this reaches hypridle without stopping it. Auto never touches the
//   manual inhibitor: releasing it on pause/stop leaves a manual "on" in place.
//
// Turn auto off with marchyo.shell.settings.caffeine.autoVideo = false.
QtObject {
    id: root

    // Manual inhibitor present (pgrep probe).
    property bool manual: false

    // Effective keep-awake state: manual or auto.
    readonly property bool active: manual || autoActive

    readonly property bool autoEnabled: {
        const c = ShellConfig.config && ShellConfig.config.caffeine;
        return !(c && c.autoVideo === false);
    }

    // Video heuristic (MPRIS has no reliable "is video" field): a playing
    // player counts when its identity / desktop entry / bus name is a known
    // video player or a browser, or its xesam:url has a video file extension.
    // Browsers playing audio-only also match; that is the accepted trade-off.
    readonly property var videoPlayerPattern: /mpv|vlc|celluloid|totem|showtime|haruna|kodi|smplayer|clapper|firefox|librewolf|zen|chrom|brave|vivaldi|edge|epiphany|qutebrowser|floorp/i
    readonly property var videoUrlPattern: /\.(mp4|mkv|webm|avi|mov|m4v|mpe?g|ogv|wmv|flv|ts)(\?|$)/i

    function looksLikeVideo(p): bool {
        const names = [p.identity || "", p.desktopEntry || "", p.dbusName || ""].join(" ");
        if (root.videoPlayerPattern.test(names))
            return true;
        const url = p.metadata ? (p.metadata["xesam:url"] || "") : "";
        return root.videoUrlPattern.test(String(url));
    }

    // First playing video-like player (bindings track every player's
    // isPlaying/metadata, so this re-evaluates on any playback change).
    readonly property var autoSource: {
        if (!root.autoEnabled)
            return null;
        const list = Mpris.players ? Mpris.players.values : [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.isPlaying && root.looksLikeVideo(p))
                return p;
        }
        return null;
    }

    readonly property bool autoActive: autoSource !== null
    // Display name for the tooltip ("auto: <player>"); empty when auto is off.
    readonly property string autoPlayer: autoSource ? (autoSource.identity || autoSource.desktopEntry || "media player") : ""

    function toggle() {
        toggleProc.running = true;
    }

    readonly property var probe: Process {
        id: probe
        // The [m] bracket stops this pgrep's own argv from matching its pattern
        // (a bare pattern self-matches and pins the widget "on"); only the real
        // --why=marchyo-caffeine-inhibit inhibitor matches.
        command: [Config.pgrep, "-f", "[m]archyo-caffeine-inhibit"]
        onExited: code => root.manual = (code === 0)
    }

    // Re-probes on exit rather than guessing the new state.
    readonly property var toggleProc: Process {
        id: toggleProc
        command: [Config.marchyo, "toggle", "caffeine"]
        onExited: probe.running = true
    }

    // The auto inhibitor: held for as long as the process runs; Quickshell
    // kills it when `running` drops (and the user service's cgroup takes it
    // down with the shell). systemd-inhibit ships next to the baked systemctl.
    // The tag deliberately does not contain "marchyo-caffeine-inhibit", so the
    // manual pgrep/pkill never see it.
    readonly property var autoInhibit: Process {
        id: autoInhibit
        running: root.autoActive
        command: [Config.systemctl.replace(/systemctl$/, "systemd-inhibit"), "--what=idle", "--who=marchyo", "--why=marchyo-video-inhibit", "sleep", "infinity"]
    }

    readonly property var poll: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
