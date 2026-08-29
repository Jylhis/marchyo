import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Services

// The shell's on-screen display: a small bottom-centred overlay that flashes the
// current volume, mic-mute, or backlight level whenever it changes. It replaces
// SwayOSD (retired by the marchyo.shell cutover). Triggers are native and
// pull-based — no external poke, matching the bar's philosophy:
//   * volume / mic mute -> Quickshell Pipewire bindings (a real reactive service,
//     shared with the bar and the audio panel via Services/Audio)
//   * brightness        -> a watched /sys/class/backlight/<dev> node, with the
//     brightness-key IPC poke (shell osdShow) as the reliable primary path —
//     sysfs attribute writes signal POLLPRI, which FileView's watcher misses on
//     many hosts (see README "brightness" note).
// The renderer is deliberately dumb: show(label, percent, hasBar) fills the card
// and (re)arms the hide timer; the watchers below decide when to call it.
Scope {
    id: root

    // Current card contents. Volume may read up to 150 (Pipewire allows the
    // same 150% ceiling as the bar's scroll and the audio panel); brightness
    // stays within 0–100 but the clamp simply doesn't bite.
    property string label: ""
    property int percent: 0
    property bool hasBar: true
    property bool shown: false

    // Suppress the initial binding storm: the watchers only drive the OSD once the
    // first values have settled, so the shell never flashes an OSD at startup.
    property bool primed: false

    function show(label, percent, hasBar) {
        root.label = label;
        root.percent = Math.max(0, Math.min(150, percent));
        root.hasBar = hasBar;
        root.shown = true;
        hideTimer.restart();
    }

    Timer {
        interval: 800
        running: true
        onTriggered: root.primed = true
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    // --- Volume + mic mute (native Pipewire, shared via Services/Audio) ---
    readonly property var sinkAudio: Audio.sinkAudio
    readonly property var sourceAudio: Audio.sourceAudio

    function showVolume() {
        if (!root.primed || !root.sinkAudio)
            return;
        if (root.sinkAudio.muted)
            root.show("MUTE", 0, false);
        else
            root.show("VOL", Math.round(root.sinkAudio.volume * 100), true);
    }

    Connections {
        target: root.sinkAudio
        function onVolumeChanged() {
            root.showVolume();
        }
        function onMutedChanged() {
            root.showVolume();
        }
    }

    Connections {
        target: root.sourceAudio
        function onMutedChanged() {
            if (!root.primed || !root.sourceAudio)
                return;
            // Show the mic's level while live (a bar), a plain card when muted —
            // mirroring the sink case instead of an empty unmute card.
            if (root.sourceAudio.muted)
                root.show("MIC MUTE", 0, false);
            else
                root.show("MIC", Math.round(root.sourceAudio.volume * 100), true);
        }
    }

    // --- Brightness (watched sysfs backlight node) ---
    property string backlightDir: ""
    property int brightnessMax: 1

    // Discover the backlight device once at startup: the first entry under
    // /sys/class/backlight (laptops have exactly one). Uses the baked coreutils
    // `ls` so it never relies on the session PATH.
    Process {
        running: true
        command: [Config.ls, "/sys/class/backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dev = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0)[0];
                if (dev)
                    root.backlightDir = "/sys/class/backlight/" + dev;
            }
        }
    }

    FileView {
        path: root.backlightDir ? root.backlightDir + "/max_brightness" : ""
        blockLoading: true
        onLoaded: root.brightnessMax = parseInt(text().trim()) || 1
    }

    FileView {
        id: brightnessFile
        path: root.backlightDir ? root.backlightDir + "/brightness" : ""
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            brightnessFile.reload();
            if (!root.primed)
                return;
            const cur = parseInt(brightnessFile.text().trim());
            if (!isNaN(cur) && root.brightnessMax > 0)
                root.show("BRT", Math.round(100 * cur / root.brightnessMax), true);
        }
    }

    // --- Surface: a passive, click-through, bottom-centred overlay ---
    PanelWindow {
        visible: root.shown
        color: "transparent"
        exclusiveZone: 0

        anchors.bottom: true
        margins.bottom: Style.osdMargin

        // Never intercept clicks — the OSD is a readout, not a control.
        mask: Region {}

        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Style.osdRadius
            color: Color.surface
            border.color: Color.border
            border.width: 1

            implicitWidth: content.implicitWidth + Style.osdPad * 2
            implicitHeight: content.implicitHeight + Style.osdPad * 2

            Row {
                id: content
                anchors.centerIn: parent
                spacing: Style.spacing * 2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label
                    color: Color.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasBar
                    width: Style.osdBarWidth
                    height: Style.osdBarHeight
                    radius: height / 2
                    color: Color.bgSubtle

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        // Cap the filled bar at 100% of the track even though
                        // the label may read up to 150.
                        width: parent.width * Math.min(100, root.percent) / 100
                        height: parent.height
                        radius: height / 2
                        color: Color.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasBar
                    text: root.percent + "%"
                    color: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                }
            }
        }
    }
}
