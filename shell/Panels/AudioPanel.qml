import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Services

// Summoned from AudioWidget. Default-sink volume/mute plus an output-device
// picker, all on native Pipewire bindings (the same Services/Audio the bar
// widget and OSD use). "wiremix" opens the full mixer TUI for anything this
// doesn't cover.
Panel {
    id: root
    panelId: "audio"
    title: "Audio"

    readonly property var sink: Audio.sink
    readonly property var audio: Audio.sinkAudio

    // Real output sinks, excluding per-application stream nodes.
    readonly property var sinks: {
        const out = [];
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.isSink && !n.isStream)
                out.push(n);
        }
        return out;
    }

    function sinkLabel(n) {
        return n ? (n.description || n.nickname || n.name) : "No output";
    }

    body: [
        Text {
            Layout.fillWidth: true
            text: root.sinkLabel(root.sink)
            color: Color.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            elide: Text.ElideRight
        },
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing

            Text {
                Layout.preferredWidth: Style.panelWidth / 4
                text: root.audio ? (root.audio.muted ? "muted" : Math.round(root.audio.volume * 100) + "%") : "n/a"
                color: (root.audio && root.audio.muted) ? Color.textFaint : Color.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
            }

            Item {
                Layout.fillWidth: true
            }

            PanelButton {
                text: "-"
                onClicked: {
                    if (root.audio)
                        root.audio.volume = Math.max(0.0, root.audio.volume - 0.05);
                }
            }

            PanelButton {
                text: "+"
                onClicked: {
                    if (root.audio)
                        root.audio.volume = Math.min(1.5, root.audio.volume + 0.05);
                }
            }

            PanelButton {
                text: (root.audio && root.audio.muted) ? "unmute" : "mute"
                active: root.audio ? root.audio.muted : false
                onClicked: {
                    if (root.audio)
                        root.audio.muted = !root.audio.muted;
                }
            }
        },
        Repeater {
            model: root.sinks

            PanelButton {
                required property var modelData
                Layout.fillWidth: true
                text: root.sinkLabel(modelData)
                active: modelData === root.sink
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        },

        // Per-application playback streams: name, live meter, volume, mute.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Style.spacing
            visible: Audio.appStreams.length > 0
            text: "Applications"
            color: Color.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        Repeater {
            model: Audio.appStreams

            ColumnLayout {
                id: appRow
                required property var modelData
                readonly property var a: modelData ? modelData.audio : null
                Layout.fillWidth: true
                spacing: 2

                // Live per-stream peak meter (v0.3.0 PwNodePeakMonitor); only
                // sampled while the panel is open.
                PwNodePeakMonitor {
                    id: mon
                    node: appRow.modelData
                    enabled: root.visible
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacing

                    Text {
                        Layout.fillWidth: true
                        text: Audio.streamLabel(appRow.modelData)
                        color: Color.text
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        elide: Text.ElideRight
                    }
                    Text {
                        text: appRow.a ? (appRow.a.muted ? "muted" : Math.round(appRow.a.volume * 100) + "%") : ""
                        color: (appRow.a && appRow.a.muted) ? Color.textFaint : Color.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                    }
                    PanelButton {
                        text: "-"
                        onClicked: {
                            if (appRow.a)
                                appRow.a.volume = Math.max(0.0, appRow.a.volume - 0.05);
                        }
                    }
                    PanelButton {
                        text: "+"
                        onClicked: {
                            if (appRow.a)
                                appRow.a.volume = Math.min(1.5, appRow.a.volume + 0.05);
                        }
                    }
                    PanelButton {
                        text: (appRow.a && appRow.a.muted) ? "unmute" : "mute"
                        active: appRow.a ? appRow.a.muted : false
                        onClicked: {
                            if (appRow.a)
                                appRow.a.muted = !appRow.a.muted;
                        }
                    }
                }

                Rectangle {
                    id: meterTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    color: Color.surface

                    Rectangle {
                        width: meterTrack.width * Math.max(0, Math.min(1, mon.peak))
                        height: meterTrack.height
                        color: Color.accent
                    }
                }
            }
        },

        // Microphone-in-use privacy indicator: which applications are capturing.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Style.spacing
            visible: Audio.micInUse
            text: "󰍬 Microphone in use"
            color: Color.statusWarn
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        Repeater {
            model: Audio.captureStreams

            Text {
                required property var modelData
                Layout.fillWidth: true
                text: "  " + Audio.streamLabel(modelData)
                color: Color.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                elide: Text.ElideRight
            }
        },
        PanelButton {
            Layout.fillWidth: true
            text: "wiremix"
            onClicked: Quickshell.execDetached([Config.terminal, "--class=org.omarchy.wiremix", "-e", Config.wiremix])
        }
    ]
}
