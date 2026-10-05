import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import "../Commons/Overview.js" as Ov

// One monitor's overview: a full-screen layer-shell overlay with the search
// field and a grid of workspace tiles holding live window previews. Escape,
// an outside click, or activating a window closes it. Only the overlay on
// the focused output takes keyboard focus; the others mirror the shared
// query and selection. The content is a Loader active only while open, so
// no preview (and no screencopy capture) exists while closed.
PanelWindow {
    id: root

    readonly property string screenName: root.screen ? root.screen.name : ""
    // The overlay that owns the keyboard: the focused output, or the first
    // screen when the compositor reports none.
    readonly property bool primary: Screens.focusedName !== "" ? root.screenName === Screens.focusedName : (Quickshell.screens.length > 0 && Quickshell.screens[0].name === root.screenName)

    visible: Overview.open
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "marchyo:overview"
    WlrLayershell.keyboardFocus: Overview.open && root.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Loader {
        id: content
        anchors.fill: parent
        active: Overview.open
        sourceComponent: contentComponent
    }

    Component {
        id: contentComponent

        Item {
            id: body

            // Declared first so the search card and tiles sit on top of it.
            MouseArea {
                anchors.fill: parent
                onClicked: Overview.close()
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Color.scrim, 0.45)
            }

            readonly property int gap: Style.panelPad
            readonly property int rows: Math.max(1, Math.ceil(Overview.groups.length / Overview.columns))
            readonly property var tile: Ov.tileSize(body.width - 4 * body.gap, body.height - search.height - 6 * body.gap - Style.barHeight, Overview.columns, body.rows, body.gap, root.width > 0 && root.height > 0 ? root.width / root.height : 16 / 9)

            Rectangle {
                id: search
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.barMarginV + Style.barHeight + 2 * body.gap
                width: Math.min(Style.launcherWidth, parent.width - 2 * body.gap)
                implicitHeight: query.implicitHeight + Style.panelPad
                radius: Style.panelRadius
                color: Qt.alpha(Color.bg, Style.surfaceAlpha)
                border.width: Style.borderWidth
                border.color: query.activeFocus ? Color.accent : Color.border

                // Swallow clicks so they do not reach the dismiss area.
                MouseArea {
                    anchors.fill: parent
                }

                TextInput {
                    id: query
                    anchors.fill: parent
                    anchors.margins: Style.panelPad / 2
                    color: Color.text
                    selectionColor: Color.selectionBg
                    selectedTextColor: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    clip: true
                    text: Overview.query

                    onTextChanged: if (Overview.query !== text)
                        Overview.query = text

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: query.text.length === 0
                        text: "Search windows"
                        color: Color.textMuted
                        font: query.font
                    }

                    Keys.onPressed: event => {
                        const k = event.key;
                        if (k === Qt.Key_Escape) {
                            Overview.close();
                        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                            Overview.activateSelected();
                        } else if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                            Overview.move(-1);
                        } else if (k === Qt.Key_Tab) {
                            Overview.move(1);
                        } else if (k === Qt.Key_Up) {
                            Overview.moveRow(-1);
                        } else if (k === Qt.Key_Down) {
                            Overview.moveRow(1);
                        } else if (k === Qt.Key_Left && query.text.length === 0) {
                            Overview.move(-1);
                        } else if (k === Qt.Key_Right && query.text.length === 0) {
                            Overview.move(1);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }

            Grid {
                id: grid
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: search.bottom
                anchors.topMargin: 2 * body.gap
                columns: Overview.columns
                spacing: body.gap

                Repeater {
                    model: Overview.groups

                    WorkspaceTile {
                        required property var modelData
                        workspace: modelData
                        width: body.tile.w
                        height: body.tile.h
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: Overview.groups.length === 0
                text: "no workspaces"
                color: Color.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
            }

            Component.onCompleted: {
                root.queryField = query;
                root.takeFocus();
            }
        }
    }

    // The loaded content's search field (ids do not cross the Component).
    property TextInput queryField: null

    function takeFocus() {
        if (!root.primary || !root.queryField)
            return;
        root.queryField.forceActiveFocus();
        focusRetry.restart();
    }

    onPrimaryChanged: root.takeFocus()

    // Map-then-focus retry, as in Launcher/LauncherWindow: the first
    // forceActiveFocus() can land before the surface accepts keyboard focus.
    Timer {
        id: focusRetry
        interval: 50
        onTriggered: if (root.visible && root.primary && root.queryField)
            root.queryField.forceActiveFocus()
    }
}
