import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Displays.js" as D

// Display settings, one display at a time: on/off, brightness, scale,
// resolution and refresh rate, and (with more than one display) a layout map
// to drag displays around in, right-click to rotate, and Extend|Mirror for the
// built-in panel. State and actions live in Services/Displays; the choices
// come from Commons/Displays.js.
Panel {
    id: root
    panelId: "display"
    title: I18n.t("display.title")
    cardWidth: Style.panelWidth * 1.6

    property string contextName: ""

    readonly property var display: Displays.current
    readonly property bool single: Displays.displays.length < 2

    onVisibleChanged: {
        contextName = "";
        if (visible)
            Displays.open();
    }

    function titleOf(d): string {
        return D.displayTitle(d, I18n.t("display.builtIn"));
    }

    component Caption: Text {
        Layout.fillWidth: true
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        elide: Text.ElideRight
    }

    body: [
        Caption {
            visible: Displays.displays.length === 0
            text: I18n.t("display.noDisplays")
        },
        Flow {
            Layout.fillWidth: true
            spacing: Style.spacing
            visible: !root.single

            Repeater {
                model: Displays.displays

                PanelButton {
                    required property var modelData
                    text: root.titleOf(modelData)
                    active: modelData.name === Displays.selected
                    onClicked: Displays.select(modelData.name)
                }
            }
        },
        RowLayout {
            Layout.fillWidth: true
            visible: root.display !== null
            spacing: Style.spacing

            Text {
                Layout.fillWidth: true
                text: root.display ? root.titleOf(root.display) + "  " + root.display.name : ""
                color: Colors.textHeading
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                font.bold: true
                elide: Text.ElideRight
            }
            PanelButton {
                visible: root.display !== null && !root.single
                text: root.display && root.display.enabled ? I18n.t("display.on") : I18n.t("display.off")
                active: root.display !== null && root.display.enabled
                onClicked: Displays.setEnabled(root.display.name, !root.display.enabled)
            }
        },
        Caption {
            visible: root.display !== null && root.display.enabled
            text: root.display ? root.display.width + "x" + root.display.height + " @ " + Math.round(root.display.refreshRate) + " Hz  " + (root.display.transform !== 0 ? I18n.t("display.rotation", D.degreesOf(root.display.transform)) : "") : ""
        },
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.display !== null && root.display.enabled && Displays.brightness[root.display.name] !== undefined

            Caption {
                text: I18n.t("display.brightness") + "  " + (root.display ? (Displays.brightness[root.display.name] || 0) : 0) + "%"
            }
            PanelSlider {
                Layout.fillWidth: true
                value: root.display ? (Displays.brightness[root.display.name] || 0) / 100 : 0
                onMoved: v => Displays.setBrightness(root.display.name, Math.round(v * 100))
            }
        },
        Caption {
            visible: root.display !== null && root.display.enabled && Displays.ddcProbed && Displays.brightness[root.display.name] === undefined
            text: I18n.t("display.fixedBrightness")
        },
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.display !== null && root.display.enabled

            Caption {
                text: I18n.t("display.scale")
            }
            Flow {
                Layout.fillWidth: true
                spacing: Style.spacing

                Repeater {
                    model: root.display ? D.availableScales(root.display.width, root.display.height) : []

                    PanelButton {
                        required property real modelData
                        text: modelData + "x"
                        active: Math.abs(modelData - (root.display ? root.display.scale : 0)) < 0.01
                        onClicked: Displays.setScale(root.display.name, modelData)
                    }
                }
            }
        },
        ColumnLayout {
            id: resolutionRow
            Layout.fillWidth: true
            spacing: 2
            readonly property var sizes: root.display ? D.resolutionOptions(root.display.modes, root.display.width, root.display.height) : []
            visible: root.display !== null && root.display.enabled && resolutionRow.sizes.length > 1

            Caption {
                text: I18n.t("display.resolution")
            }
            Flow {
                Layout.fillWidth: true
                spacing: Style.spacing

                Repeater {
                    model: resolutionRow.sizes

                    PanelButton {
                        required property string modelData
                        text: D.resolutionLabel(modelData)
                        active: root.display !== null && modelData === root.display.width + "x" + root.display.height
                        onClicked: Displays.setMode(root.display.name, modelData, "")
                    }
                }
            }
        },
        ColumnLayout {
            id: refreshRow
            Layout.fillWidth: true
            spacing: 2
            readonly property var rates: root.display ? D.refreshOptions(root.display.modes, root.display.width, root.display.height) : []
            visible: root.display !== null && root.display.enabled && refreshRow.rates.length > 1

            Caption {
                text: I18n.t("display.refresh")
            }
            Flow {
                Layout.fillWidth: true
                spacing: Style.spacing

                Repeater {
                    model: refreshRow.rates

                    PanelButton {
                        required property var modelData
                        text: modelData.label + " Hz"
                        active: root.display !== null && Math.abs(Number(modelData.rate) - root.display.refreshRate) < 0.5
                        onClicked: Displays.setMode(root.display.name, root.display.width + "x" + root.display.height, modelData.rate)
                    }
                }
            }
        },
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: Displays.layout.length > 0

            Caption {
                text: I18n.t("display.layout")
            }

            Item {
                id: map
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                readonly property int pad: 8
                readonly property var rects: Displays.layout.map(D.logicalRect)
                readonly property var bounds: rects.length > 0 ? D.layoutBounds(rects) : {
                    x: 0,
                    y: 0,
                    w: 1,
                    h: 1
                }
                readonly property real factor: Math.min((width - 2 * pad) / Math.max(1, bounds.w), (height - 2 * pad) / Math.max(1, bounds.h))
                readonly property real offX: pad + (width - 2 * pad - bounds.w * factor) / 2
                readonly property real offY: pad + (height - 2 * pad - bounds.h * factor) / 2

                Rectangle {
                    anchors.fill: parent
                    radius: Style.panelRadius
                    color: Colors.bgSubtle
                    border.color: Colors.border
                    border.width: 1
                }

                Repeater {
                    model: map.rects

                    Rectangle {
                        id: tile
                        required property var modelData
                        readonly property var info: Displays.byName(modelData.name)
                        readonly property bool chosen: modelData.name === Displays.selected
                        property real shiftX: 0
                        property real shiftY: 0
                        property bool settling: false
                        Behavior on shiftX {
                            enabled: tile.settling && !Style.reduceMotion
                            NumberAnimation {
                                duration: Style.duration(160)
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on shiftY {
                            enabled: tile.settling && !Style.reduceMotion
                            NumberAnimation {
                                duration: Style.duration(160)
                                easing.type: Easing.OutCubic
                            }
                        }

                        x: map.offX + (modelData.x - map.bounds.x) * map.factor + shiftX
                        y: map.offY + (modelData.y - map.bounds.y) * map.factor + shiftY
                        width: Math.max(8, modelData.w * map.factor)
                        height: Math.max(8, modelData.h * map.factor)
                        radius: 4
                        z: area.pressed ? 2 : 1
                        color: chosen ? Colors.accentSubtle : Colors.surfaceRaised
                        border.color: activeFocus ? Style.control("focus").border : (chosen ? Colors.accent : Colors.border)
                        border.width: activeFocus ? Style.borderFocus : Style.borderWidth

                        // Keyboard: Tab reaches a tile and selects its display,
                        // Shift+arrows nudge it one step, R rotates (the
                        // right-click action). Up and Down without Shift stay
                        // with the panel's focus walk.
                        activeFocusOnTab: true
                        onActiveFocusChanged: {
                            if (activeFocus)
                                Displays.select(modelData.name);
                        }
                        Keys.onPressed: e => {
                            const step = D.NUDGE_STEP;
                            const shifted = (e.modifiers & Qt.ShiftModifier) !== 0;
                            const dx = e.key === Qt.Key_Left ? -step : e.key === Qt.Key_Right ? step : 0;
                            const dy = shifted ? (e.key === Qt.Key_Up ? -step : e.key === Qt.Key_Down ? step : 0) : 0;
                            if (e.key === Qt.Key_R) {
                                Displays.rotate(modelData.name);
                            } else if (dx !== 0 || dy !== 0) {
                                Displays.drop(modelData.name, modelData.x + dx, modelData.y + dy);
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                                Displays.select(modelData.name);
                            } else {
                                return;
                            }
                            e.accepted = true;
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 4
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name + (tile.info && tile.info.transform !== 0 ? "  " + D.degreesOf(tile.info.transform) + "°" : "")
                            color: tile.chosen ? Colors.accent : Colors.text
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: area
                            property point origin: Qt.point(0, 0)
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Displays.layout.length < 2 ? Qt.PointingHandCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            onPressed: mouse => {
                                tile.settling = false;
                                root.contextName = "";
                                tile.forceActiveFocus();
                                origin = mapToItem(map, mouse.x, mouse.y);
                                Displays.select(tile.modelData.name);
                            }
                            onPositionChanged: mouse => {
                                if (!pressed || !(mouse.buttons & Qt.LeftButton) || Displays.layout.length < 2)
                                    return;
                                const p = mapToItem(map, mouse.x, mouse.y);
                                tile.shiftX = p.x - origin.x;
                                tile.shiftY = p.y - origin.y;
                            }
                            onReleased: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.contextName = tile.modelData.name;
                                    return;
                                }
                                const moved = Math.abs(tile.shiftX) + Math.abs(tile.shiftY) > 4;
                                const cornerX = map.bounds.x + (tile.x - map.offX) / map.factor;
                                const cornerY = map.bounds.y + (tile.y - map.offY) / map.factor;
                                tile.settling = true;
                                tile.shiftX = 0;
                                tile.shiftY = 0;
                                if (moved)
                                    Displays.drop(tile.modelData.name, cornerX, cornerY);
                            }
                        }
                    }
                }
            }

            Caption {
                text: I18n.t(Displays.layout.length > 1 ? "display.layoutHint" : "display.rotateHint")
                color: Colors.textFaint
            }
        },
        PopupCard {
            Layout.fillWidth: true
            visible: root.contextName !== "" && Displays.byName(root.contextName) !== null
            title: root.contextName
            Keys.onEscapePressed: root.contextName = ""

            Flow {
                Layout.fillWidth: true
                spacing: Style.spacing
                Repeater {
                    model: [0, 90, 180, 270]
                    PanelButton {
                        required property int modelData
                        text: modelData === 0 ? I18n.t("display.normal") : modelData + "°"
                        active: {
                            const d = Displays.byName(root.contextName);
                            return d !== null && D.degreesOf(d.transform) === modelData;
                        }
                        onClicked: {
                            Displays.setRotation(root.contextName, modelData);
                            root.contextName = "";
                        }
                    }
                }
            }
            Repeater {
                model: Displays.layout.filter(d => d.name !== root.contextName)
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    PanelButton {
                        text: I18n.t("display.placeLeft", parent.modelData.name)
                        onClicked: {
                            Displays.placeBeside(root.contextName, parent.modelData.name, false);
                            root.contextName = "";
                        }
                    }
                    PanelButton {
                        text: I18n.t("display.placeRight", parent.modelData.name)
                        onClicked: {
                            Displays.placeBeside(root.contextName, parent.modelData.name, true);
                            root.contextName = "";
                        }
                    }
                }
            }
        },
        Caption {
            visible: Displays.mirrorError !== ""
            text: Displays.mirrorError
            color: Colors.statusErr
        },
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing
            visible: D.canMirror(Displays.displays)
            enabled: Displays.mirrorWanted === null

            PanelButton {
                Layout.fillWidth: true
                text: I18n.t("display.extend")
                active: !D.isMirrored(Displays.displays)
                onClicked: Displays.setMirror(false)
            }
            PanelButton {
                Layout.fillWidth: true
                text: I18n.t("display.mirror")
                active: D.isMirrored(Displays.displays)
                onClicked: Displays.setMirror(true)
            }
        }
    ]
}
