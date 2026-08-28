import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons

// The shell's on-screen display: a small bottom-centred overlay that flashes the
// current volume, mic-mute, or backlight level whenever it changes. It replaces
// SwayOSD (retired by the marchyo.shell cutover). Triggers are native and
// pull-based — no external poke, matching the bar's philosophy:
//   * volume / mic mute -> Quickshell Pipewire bindings (a real reactive service)
//   * brightness        -> a watched /sys/class/backlight/<dev>/brightness node
// The renderer is deliberately dumb: show(label, percent, hasBar) fills the card
// and (re)arms the hide timer; the watchers below decide when to call it.
Scope {
    id: root

    // Current card contents.
    property string label: ""
    property int percent: 0
    property bool hasBar: true
    property bool shown: false

    // Suppress the initial binding storm: the watchers only drive the OSD once the
    // first values have settled, so the shell never flashes an OSD at startup.
    property bool primed: false

    function show(label, percent, hasBar) {
        root.label = label;
        root.percent = Math.max(0, Math.min(100, percent));
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

    // --- Volume + mic mute (native Pipewire) ---
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source ? source.audio : null

    // Without an object tracker the nodes' audio properties never bind/update.
    PwObjectTracker {
        objects: {
            const list = [];
            if (root.sink)
                list.push(root.sink);
            if (root.source)
                list.push(root.source);
            return list;
        }
    }

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
            if (!root.primed)
                return;
            root.show(root.sourceAudio.muted ? "MIC MUTE" : "MIC", 0, false);
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
                        width: parent.width * root.percent / 100
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
