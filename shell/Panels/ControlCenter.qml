import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Services

// Quick-settings surface: output volume and microphone sliders over
// Services/Audio (plus a live mic input meter), and a tile grid over the
// Services/QuickToggles model. A tile click flips its toggle; a tile's chevron
// opens the existing detail panel (audio, network, power, tailscale,
// notifications) through PanelManager.openDetail, whose back button returns
// here. Glyphs are code points because editing tools strip Private Use Area
// characters from source.
Panel {
    id: root
    panelId: "controlcenter"
    title: "Control Center"
    cardWidth: Style.controlCenterWidth

    readonly property var sinkAudio: Audio.sinkAudio
    readonly property var sourceAudio: Audio.sourceAudio

    function glyph(cp: int): string {
        return String.fromCodePoint(cp);
    }

    function pct(a): string {
        return a ? Math.round(a.volume * 100) + "%" : "n/a";
    }

    component LevelRow: RowLayout {
        id: row
        required property var level
        required property int iconOn
        required property int iconMuted
        property string detail: ""

        readonly property bool muted: row.level ? row.level.muted : false

        Layout.fillWidth: true
        spacing: Style.spacing

        PanelButton {
            text: root.glyph(row.muted ? row.iconMuted : row.iconOn)
            active: row.muted
            onClicked: {
                if (row.level)
                    row.level.muted = !row.level.muted;
            }
        }

        PanelSlider {
            Layout.fillWidth: true
            value: row.level ? row.level.volume : 0
            dimmed: row.muted || !row.level
            onMoved: v => {
                if (row.level)
                    row.level.volume = v;
            }
        }

        Text {
            Layout.preferredWidth: Style.panelRowHeight * 1.5
            horizontalAlignment: Text.AlignRight
            text: root.pct(row.level)
            color: row.muted ? Color.textFaint : Color.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }

        PanelButton {
            visible: row.detail !== ""
            text: "›"
            onClicked: PanelManager.openDetail(row.detail, root.panelId)
        }
    }

    body: [
        LevelRow {
            level: root.sinkAudio
            iconOn: 0xF057E
            iconMuted: 0xF075F
            detail: "audio"
        },
        LevelRow {
            level: root.sourceAudio
            iconOn: 0xF036C
            iconMuted: 0xF036D
        },
        // Live microphone input level under the mic slider. The peak monitor
        // opens a capture tap on the default source, so it runs only while the
        // Control Center is open and the mic is live (Services/Audio keeps the
        // tap out of the mic-in-use list).
        Rectangle {
            id: micMeter
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            visible: root.sourceAudio !== null && !root.sourceAudio.muted
            color: Color.surface

            PwNodePeakMonitor {
                id: micPeak
                node: Audio.source
                enabled: root.visible && micMeter.visible
            }

            Rectangle {
                width: micMeter.width * Math.max(0, Math.min(1, micPeak.peak))
                height: micMeter.height
                color: Color.accent
            }
        },
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Style.spacing
            columns: 2
            columnSpacing: Style.spacing
            rowSpacing: Style.spacing

            Repeater {
                model: QuickToggles.all

                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool on: tile.modelData.active

                    visible: tile.modelData.available
                    Layout.fillWidth: true
                    // Equal preferred widths split the two columns evenly.
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Style.tileHeight
                    radius: Style.panelRadius
                    color: tile.on ? Color.accentSubtle : (tileMouse.containsMouse ? Color.surfaceRaised : Color.bgSubtle)
                    border.color: tile.on ? Color.accent : Color.border
                    border.width: Style.borderWidth

                    // Whole-tile click flips the toggle. Declared before the
                    // content so the chevron's own MouseArea sits above it.
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tile.modelData.toggle()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.paddingH * 2
                        anchors.rightMargin: Style.paddingH
                        spacing: Style.paddingH

                        Text {
                            text: tile.modelData.icon
                            color: tile.on ? Color.accent : Color.textMuted
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSize + 4
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: tile.modelData.label
                                color: Color.text
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizeSmall
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: tile.modelData.status
                                color: Color.textMuted
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizeSmall
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: chevron
                            visible: tile.modelData.detail !== ""
                            Layout.fillHeight: true
                            Layout.preferredWidth: Style.panelRowHeight * 0.7
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "›"
                            color: chevronMouse.containsMouse ? Color.accent : Color.textMuted
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSize + 4

                            MouseArea {
                                id: chevronMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PanelManager.openDetail(tile.modelData.detail, root.panelId)
                            }
                        }
                    }
                }
            }
        }
    ]
}
