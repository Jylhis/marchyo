import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Elsewhen.js" as E

// World clock: a coastline map with the tracked cities, then one row per city
// with its local time and offset from home. Click a row to make it home; the
// `+` search finds places through Open-Meteo. State lives in Services/Elsewhen.
// Keys: t flips 12/24 hour, Alt+T flips C/F, / searches, Esc closes.
Panel {
    id: root
    panelId: "elsewhen"
    title: I18n.t("elsewhen.title")
    cardWidth: Style.controlCenterWidth + 100

    property int editIndex: -1

    keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: {
        Elsewhen.active = root.visible;
        if (root.visible) {
            root.editIndex = -1;
            searchField.text = "";
            keys.forceActiveFocus();
        }
    }

    readonly property var homeParts: E.zoneParts(Elsewhen.nowMs, Elsewhen.homeOffset)

    // Natural Earth 110m coastlines (public domain): rings of flat lon,lat pairs.
    readonly property var worldFile: FileView {
        id: worldFile
        path: Quickshell.shellDir + "/Panels/world.json"
        blockLoading: true
        printErrors: false
    }
    readonly property var world: {
        try {
            return JSON.parse(worldFile.text());
        } catch (e) {
            return [];
        }
    }

    function dayText(delta: int): string {
        if (delta > 0)
            return I18n.t("elsewhen.tomorrow");
        if (delta < 0)
            return I18n.t("elsewhen.yesterday");
        return I18n.t("elsewhen.today");
    }

    function submitSearch(): void {
        if (Elsewhen.results.length > 0)
            Elsewhen.addCity(Elsewhen.results[0]);
        searchField.text = "";
        keys.forceActiveFocus();
    }

    component Muted: Text {
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        elide: Text.ElideRight
    }

    body: [
        Item {
            id: keys
            Layout.preferredHeight: 0
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_T && (event.modifiers & Qt.AltModifier)) {
                    Elsewhen.toggle("useF");
                } else if (event.key === Qt.Key_T && event.modifiers === Qt.NoModifier) {
                    Elsewhen.toggle("use24h");
                } else if (event.key === Qt.Key_Slash || event.key === Qt.Key_Plus) {
                    searchField.focusInput();
                } else {
                    return;
                }
                event.accepted = true;
            }
        },
        Canvas {
            id: map
            Layout.fillWidth: true
            Layout.preferredHeight: width / 2
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = String(Colors.border);
                ctx.lineWidth = 1;
                for (const ring of root.world) {
                    ctx.beginPath();
                    for (let i = 0; i + 1 < ring.length; i += 2) {
                        const p = E.project(ring[i + 1], ring[i], width, height);
                        if (i === 0)
                            ctx.moveTo(p.x, p.y);
                        else
                            ctx.lineTo(p.x, p.y);
                    }
                    ctx.stroke();
                }
                for (const c of Elsewhen.cfg.cities) {
                    const p = E.project(c.lat, c.lon, width, height);
                    ctx.fillStyle = String(c.tz === Elsewhen.cfg.home ? Colors.accent : Colors.text);
                    ctx.beginPath();
                    ctx.arc(p.x, p.y, 3, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }
            Connections {
                target: Elsewhen
                function onCfgChanged() {
                    map.requestPaint();
                }
            }
            Connections {
                target: Colors
                function onAccentChanged() {
                    map.requestPaint();
                }
            }
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
        },
        FilterInput {
            id: searchField
            Layout.fillWidth: true
            placeholderText: I18n.t("elsewhen.search")
            onTextChanged: Elsewhen.search(text)
            onSubmitted: root.submitSearch()
            onCleared: keys.forceActiveFocus()
        },
        Muted {
            Layout.fillWidth: true
            visible: Elsewhen.searching
            text: I18n.t("elsewhen.searching")
        },
        Repeater {
            model: Elsewhen.results

            PanelButton {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.name + (modelData.region !== "" ? ", " + modelData.region : "") + (modelData.country !== "" ? " (" + modelData.country + ")" : "")
                onClicked: {
                    Elsewhen.addCity(modelData);
                    searchField.text = "";
                    keys.forceActiveFocus();
                }
            }
        },
        Repeater {
            model: Elsewhen.cfg.cities

            Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool isHome: row.modelData.tz === Elsewhen.cfg.home
                readonly property var parts: Elsewhen.partsFor(row.modelData.tz)
                readonly property int offset: Elsewhen.offsetOf(row.modelData.tz)
                readonly property string temp: E.formatTemp(Elsewhen.temps[row.index], Elsewhen.cfg.useF)

                Layout.fillWidth: true
                implicitHeight: rowLayout.implicitHeight + Style.spacing * 2
                radius: Style.panelRadius
                color: row.isHome ? Colors.accentSubtle : (rowMouse.containsMouse ? Colors.surfaceRaised : Colors.bgSubtle)
                border.color: row.isHome ? Colors.accent : Colors.border
                border.width: 1

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Elsewhen.toggleHome(row.modelData.tz)
                }

                RowLayout {
                    id: rowLayout
                    anchors.fill: parent
                    anchors.margins: Style.spacing
                    anchors.leftMargin: Style.panelPad
                    anchors.rightMargin: Style.panelPad
                    spacing: Style.spacing * 2

                    Text {
                        text: E.isDaytime(row.parts) ? "󰖙" : "󰖔"
                        color: E.isDaytime(row.parts) ? Colors.statusWarn : Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name + (row.isHome ? "  " + I18n.t("elsewhen.home") : "")
                            color: Colors.textHeading
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSize
                            elide: Text.ElideRight
                        }
                        Muted {
                            Layout.fillWidth: true
                            text: E.weekdayShort(row.parts) + " " + root.dayText(E.dayDelta(row.parts, root.homeParts)) + "  ·  " + E.offsetLabel(row.offset) + "  ·  " + E.relativeOffset(row.offset, Elsewhen.homeOffset) + (row.temp !== "" ? "  ·  " + row.temp : "")
                        }
                        Muted {
                            Layout.fillWidth: true
                            visible: row.modelData.people.length > 0 && root.editIndex !== row.index
                            text: row.modelData.people.join(", ")
                            color: Colors.text
                        }
                        TextInput {
                            id: peopleField
                            Layout.fillWidth: true
                            visible: root.editIndex === row.index
                            color: Colors.text
                            selectionColor: Colors.accent
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                            clip: true
                            onVisibleChanged: {
                                if (visible) {
                                    text = row.modelData.people.join(", ");
                                    forceActiveFocus();
                                }
                            }
                            onAccepted: {
                                Elsewhen.setPeople(row.index, text);
                                root.editIndex = -1;
                                keys.forceActiveFocus();
                            }
                            Keys.onEscapePressed: {
                                root.editIndex = -1;
                                keys.forceActiveFocus();
                            }
                        }
                    }

                    Text {
                        text: E.formatClock(row.parts, Elsewhen.cfg.use24h)
                        color: Colors.textHeading
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize + 4
                        font.bold: true
                    }

                    Text {
                        text: "󰀄"
                        color: peopleMouse.containsMouse ? Colors.accent : Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        MouseArea {
                            id: peopleMouse
                            anchors.fill: parent
                            anchors.margins: -Style.spacing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editIndex = root.editIndex === row.index ? -1 : row.index
                        }
                    }

                    Text {
                        visible: Elsewhen.cfg.cities.length > 1
                        text: "×"
                        color: removeMouse.containsMouse ? Colors.statusErr : Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            anchors.margins: -Style.spacing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Elsewhen.removeCity(row.index)
                        }
                    }
                }
            }
        },
        Muted {
            Layout.fillWidth: true
            text: I18n.t("elsewhen.hints")
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    ]
}
