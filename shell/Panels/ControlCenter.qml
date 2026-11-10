import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Services

// Quick-settings surface: output volume and microphone sliders over
// Services/Audio (plus a live mic input meter), and a tile grid over the
// Services/QuickToggles model. A tile click flips its toggle; a tile's chevron
// opens the existing detail panel (audio, network, power, tailscale,
// notifications) through PanelManager.openDetail, whose back button returns
// here. An Appearance section under the tiles drives window gaps, the bar
// position and background and reduce-motion through the marchyo CLI, and opens
// the themes and wallpapers pickers. Glyphs are code points because editing
// tools strip Private Use Area characters from source.
Panel {
    id: root
    panelId: "controlcenter"
    title: I18n.t("controlcenter.title")
    cardWidth: Style.controlCenterWidth

    readonly property var sinkAudio: Audio.sinkAudio
    readonly property var sourceAudio: Audio.sourceAudio

    function glyph(cp: int): string {
        return String.fromCodePoint(cp);
    }

    // Window gaps have no shell-side state file, so the CLI is asked each
    // time the panel opens; the toggle then follows the user's clicks.
    property bool gaps: false

    readonly property var positionOptions: [
        {
            value: "top",
            label: I18n.t("controlcenter.position.top")
        },
        {
            value: "bottom",
            label: I18n.t("controlcenter.position.bottom")
        }
    ]

    readonly property var backgroundOptions: [
        {
            value: "opaque",
            label: I18n.t("controlcenter.background.opaque")
        },
        {
            value: "glassy",
            label: I18n.t("controlcenter.background.glassy")
        },
        {
            value: "clear",
            label: I18n.t("controlcenter.background.clear")
        }
    ]

    function setGaps(on: bool): void {
        root.gaps = on;
        Quickshell.execDetached([Config.marchyo, "theme", "gaps", on ? "on" : "off"]);
    }

    function setReduceMotion(on: bool): void {
        Quickshell.execDetached([Config.marchyo, "toggle", "reduce-motion", on ? "on" : "off"]);
    }

    function setBarPosition(value: string): void {
        Quickshell.execDetached([Config.marchyo, "theme", "bar-position", value]);
    }

    function setBarBackground(value: string): void {
        Quickshell.execDetached([Config.marchyo, "theme", "bar-background", value]);
    }

    onVisibleChanged: {
        if (root.visible) {
            root.gapsProc.running = false;
            root.gapsProc.running = true;
        }
    }

    readonly property var gapsProc: Process {
        command: [Config.marchyo, "toggle", "gaps", "--status", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gaps = JSON.parse(text).toggle.on === true;
                } catch (e) {
                    root.gaps = false;
                }
            }
        }
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
            color: row.muted ? Colors.textFaint : Colors.text
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
            color: Colors.surface

            PwNodePeakMonitor {
                id: micPeak
                node: Audio.source
                enabled: root.visible && micMeter.visible
            }

            Rectangle {
                width: micMeter.width * Math.max(0, Math.min(1, micPeak.peak))
                height: micMeter.height
                color: Colors.accent
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

                ControlSurface {
                    id: tile
                    required property var modelData
                    readonly property bool on: tile.modelData.active

                    visible: tile.modelData.available
                    Layout.fillWidth: true
                    // Equal preferred widths split the two columns evenly.
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Style.tileHeight
                    selected: tile.on
                    hot: tileMouse.containsMouse
                    focused: tile.activeFocus
                    activeFocusOnTab: true

                    // Enter and Space flip the toggle; Right opens the detail page.
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                            tile.modelData.toggle();
                        } else if (e.key === Qt.Key_Right && tile.modelData.detail !== "") {
                            PanelManager.openDetail(tile.modelData.detail, root.panelId);
                        } else {
                            return;
                        }
                        e.accepted = true;
                    }

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
                            color: tile.on ? Colors.accent : Colors.textMuted
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSize + 4
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: tile.modelData.label
                                color: Colors.text
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizeSmall
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: tile.modelData.status
                                color: Colors.textMuted
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
                            color: chevronMouse.containsMouse ? Colors.accent : Colors.textMuted
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
        },
        PanelSeparator {},
        PanelSectionHeader {
            text: I18n.t("controlcenter.appearance")
        },
        Toggle {
            Layout.fillWidth: true
            label: I18n.t("controlcenter.gaps")
            checked: root.gaps
            onToggled: value => root.setGaps(value)
        },
        Text {
            text: I18n.t("controlcenter.barPosition")
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        ButtonGroup {
            id: positionGroup
            Layout.fillWidth: true
            options: root.positionOptions
            onChanged: v => root.setBarPosition(v)

            Binding {
                target: positionGroup
                property: "value"
                value: Style.barPosition
                restoreMode: Binding.RestoreNone
            }
        },
        Text {
            text: I18n.t("controlcenter.barBackground")
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        },
        ButtonGroup {
            id: backgroundGroup
            Layout.fillWidth: true
            options: root.backgroundOptions
            onChanged: v => root.setBarBackground(v)

            Binding {
                target: backgroundGroup
                property: "value"
                value: Style.barBackground
                restoreMode: Binding.RestoreNone
            }
        },
        Toggle {
            Layout.fillWidth: true
            label: I18n.t("controlcenter.reduceMotion")
            checked: RuntimeStyle.reduceMotion || Style.reduceMotion
            onToggled: value => root.setReduceMotion(value)
        },
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing

            Button {
                Layout.fillWidth: true
                text: I18n.t("controlcenter.themes")
                onClicked: PanelManager.openDetail("themes", root.panelId)
            }
            Button {
                Layout.fillWidth: true
                text: I18n.t("controlcenter.wallpapers")
                onClicked: PanelManager.openDetail("backgrounds", root.panelId)
            }
        }
    ]
}
