import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Launcher

// The launcher surface: a full-screen transparent layer-shell overlay (the
// Ui/Panel dismiss idiom) whose centered card hosts one mode view. While open
// it takes EXCLUSIVE keyboard focus and releases it when closed. Opens on the
// focused output, like PanelManager's fallback.
PanelWindow {
    id: root

    visible: Launcher.open
    screen: Screens.byName(Screens.focusedName)
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "marchyo:launcher"
    WlrLayershell.keyboardFocus: Launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // No window-level focus signal to auto-close on: PanelWindow exposes no
    // `active`, and the Exclusive keyboard grab means the compositor can't
    // silently route focus elsewhere while open. Dismissal is Escape, the
    // outside-click MouseArea below, and item activation.

    // Take focus once the surface has mapped; the focusRetry call is the one
    // that sticks on some compositors.
    onVisibleChanged: if (visible) {
        query.text = "";
        query.forceActiveFocus();
        focusRetry.restart();
    }

    // Declared first so the card sits on top of it (Ui/Panel.qml ordering trick).
    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.launcherWidth, parent.width - 2 * Style.panelGap)
        implicitHeight: Math.min(column.implicitHeight, parent.height - 2 * Style.panelGap)
        radius: 0
        color: Color.bg
        border.color: Color.border
        border.width: 1

        // Swallow clicks inside the card so they don't reach the dismiss
        // area below (Ui/Panel.qml idiom).
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.spacing

            // The one query field, shared by every mode.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.panelPad
                implicitHeight: query.implicitHeight + Style.panelPad
                color: Color.bgSubtle
                border.width: 1
                border.color: query.activeFocus ? Color.accent : Color.border

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
                    Keys.onEscapePressed: Launcher.close()

                    // Inline autocomplete: remaining letters of the top app
                    // match, dimmed after the cursor. Only apps mode offers it;
                    // emoji/clipboard have no single completion.
                    property string ghost: (Launcher.mode === "apps" && query.activeFocus && apps.suggestion.length > query.text.length) ? apps.suggestion.substring(query.text.length) : ""

                    function acceptGhost() {
                        if (query.ghost.length === 0)
                            return false;
                        query.text = apps.suggestion;
                        query.cursorPosition = query.text.length;
                        return true;
                    }

                    Text {
                        id: ghostText
                        x: query.contentWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: query.ghost
                        visible: text.length > 0
                        color: Color.textMuted
                        font: query.font
                    }

                    // Arrows/Enter are routed to the active view; each view
                    // owns its list navigation.
                    Keys.onPressed: event => {
                        if (Launcher.mode === "apps") {
                            if (event.key === Qt.Key_Down) {
                                apps.move(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                apps.move(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                query.acceptGhost();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right && query.cursorPosition === query.text.length) {
                                // Only swallow Right when it accepts a ghost;
                                // otherwise let the cursor move normally.
                                event.accepted = query.acceptGhost();
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                apps.activate();
                                event.accepted = true;
                            }
                        } else if (Launcher.mode === "emoji") {
                            if (event.key === Qt.Key_Down) {
                                emoji.move(3);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                emoji.move(-3);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left) {
                                emoji.move(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                emoji.move(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                emoji.activate();
                                event.accepted = true;
                            }
                        } else if (Launcher.mode === "clipboard") {
                            if (event.key === Qt.Key_Down) {
                                clip.move(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                clip.move(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                clip.activate();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            AppsView {
                id: apps
                anchors.left: parent.left
                anchors.right: parent.right
                visible: Launcher.mode === "apps"
                query: query.text
            }

            EmojiView {
                id: emoji
                anchors.left: parent.left
                anchors.right: parent.right
                visible: Launcher.mode === "emoji"
                query: query.text
            }

            ClipboardView {
                id: clip
                anchors.left: parent.left
                anchors.right: parent.right
                visible: Launcher.mode === "clipboard"
                query: query.text
            }
        }
    }

    // Map-then-focus retry: on some compositors forceActiveFocus() in the
    // visible-change handler lands before the surface accepts keyboard focus.
    Timer {
        id: focusRetry
        interval: 50
        onTriggered: if (root.visible)
            query.forceActiveFocus()
    }
}
