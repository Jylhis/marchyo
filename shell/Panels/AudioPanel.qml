import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/AudioDevices.js" as Devices

Panel {
    id: root
    panelId: "audio"
    title: I18n.t("audio.title")

    readonly property bool masterMuted: {
        const output = !Audio.sinkAudio || Audio.sinkAudio.muted;
        const input = !Audio.sourceAudio || Audio.sourceAudio.muted;
        return output && input;
    }

    function toggleMaster(): void {
        const mute = !root.masterMuted;
        if (Audio.sinkAudio)
            Audio.sinkAudio.muted = mute;
        if (Audio.sourceAudio)
            Audio.sourceAudio.muted = mute;
    }

    component Meter: Rectangle {
        id: meter
        required property var node
        Layout.fillWidth: true
        Layout.preferredHeight: 3
        color: Colors.bgSubtle

        PwNodePeakMonitor {
            id: monitor
            node: root.visible ? meter.node : null
            enabled: root.visible
        }

        Rectangle {
            width: meter.width * Math.max(0, Math.min(1, monitor.peak))
            height: parent.height
            color: Colors.accent
            Behavior on width {
                NumberAnimation {
                    duration: Style.reduceMotion ? 0 : 70
                }
            }
        }
    }

    component VolumeControl: ColumnLayout {
        id: volume
        required property var node
        required property string label
        readonly property var audio: node ? node.audio : null
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: volume.label
                color: Colors.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                elide: Text.ElideRight
            }
            Text {
                text: volume.audio ? Math.round(volume.audio.volume * 100) + "%" : I18n.t(
                                         "audio.unavailable")
                opacity: volume.audio && volume.audio.muted ? 0.5 : 1
                color: Colors.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
            }
            PanelButton {
                text: volume.audio && volume.audio.muted ? I18n.t("audio.unmute") : I18n.t(
                                                               "audio.mute")
                active: !!volume.audio && volume.audio.muted
                enabled: !!volume.audio
                onClicked: volume.audio.muted = !volume.audio.muted
            }
        }
        PanelSlider {
            Layout.fillWidth: true
            enabled: !!volume.audio
            value: volume.audio ? volume.audio.volume / 1.5 : 0
            step: 0.05 / 1.5
            dimmed: !!volume.audio && volume.audio.muted
            opacity: dimmed ? 0.5 : 1
            onMoved: v => volume.audio.volume = v * 1.5

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    if (volume.audio)
                        volume.audio.muted = !volume.audio.muted;
                }
            }
        }
        Meter {
            node: volume.node
        }
    }

    component DeviceRow: PanelActionButton {
        id: device
        required property var node
        property bool input: false
        Layout.fillWidth: true
        iconText: Devices.deviceGlyph(node, input)
        text: node ? node.description || node.nickname || node.name : ""
        selected: node === (input ? Audio.source : Audio.sink)
        onClicked: {
            if (input)
                Pipewire.preferredDefaultAudioSource = node;
            else
                Pipewire.preferredDefaultAudioSink = node;
        }
    }

    body: [
        PanelActionButton {
            Layout.fillWidth: true
            iconText: {
                if (root.masterMuted)
                    return "󰝟";
                const audio = Audio.sinkAudio;
                if (!audio || audio.muted || audio.volume === 0)
                    return "󰕿";
                return audio.volume < 0.5 ? "󰖀" : "󰕾";
            }
            text: I18n.t("audio.masterMute")
            hint: root.masterMuted ? I18n.t("audio.unmute") : I18n.t("audio.mute")
            onClicked: root.toggleMaster()
        },
        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.preferredHeight: {
                const chrome = Style.barHeight + Style.panelPad * 6 + Style.panelRowHeight * 2;
                return Math.min(contents.implicitHeight, Math.max(120, root.height - chrome));
            }
            contentWidth: width
            contentHeight: contents.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property var focusedItem: Window.activeFocusItem
            onFocusedItemChanged: Qt.callLater(ensureFocusVisible)

            function ensureFocusVisible(): void {
                let item = focusedItem;
                while (item && item !== contents)
                    item = item.parent;
                if (!item || !focusedItem)
                    return;
                const point = focusedItem.mapToItem(contents, 0, 0);
                const bottom = point.y + focusedItem.height;
                if (point.y < contentY)
                    contentY = Math.max(0, point.y);
                else if (bottom > contentY + height)
                    contentY = Math.min(Math.max(0, contentHeight - height), bottom - height);
            }

            ColumnLayout {
                id: contents
                width: scroll.width
                spacing: Style.spacing

                PanelSectionHeader {
                    text: I18n.t("audio.output")
                }
                VolumeControl {
                    node: Audio.sink
                    label: Audio.sink ? Audio.sink.description || Audio.sink.name : I18n.t(
                                            "audio.noOutput")

                }
                Repeater {
                    model: Audio.sinks
                    DeviceRow {
                        required property var modelData
                        node: modelData
                    }
                }
                PanelSectionHeader {
                    text: I18n.t("audio.input")
                }
                VolumeControl {
                    node: Audio.source
                    label: Audio.source ? Audio.source.description || Audio.source.name : I18n.t(
                                              "audio.noInput")

                }
                Repeater {
                    model: Audio.sources
                    DeviceRow {
                        required property var modelData
                        node: modelData
                        input: true
                    }
                }
                PanelSectionHeader {
                    visible: Audio.appStreams.length > 0
                    text: I18n.tn("audio.applications", Audio.appStreams.length,
                                  Audio.appStreams.length)
                }
                Repeater {
                    model: Audio.appStreams
                    VolumeControl {
                        required property var modelData
                        node: modelData
                        label: Audio.streamLabel(modelData)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: Audio.micInUse
                    text: "󰍬 " + I18n.t("audio.microphoneInUse")
                    color: Colors.statusWarn
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }
                Repeater {
                    model: Audio.captureStreams
                    Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: Audio.streamLabel(modelData)
                        color: Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }
                PanelButton {
                    Layout.fillWidth: true
                    text: "wiremix"
                    onClicked: Quickshell.execDetached([Config.terminal,
                                                        "--class=org.omarchy.wiremix", "-e",
                                                        Config.wiremix])
                }
            }
        }
    ]
}
