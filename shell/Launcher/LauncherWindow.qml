import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Launcher

// The launcher surface: a full-screen transparent layer-shell overlay (the
// Ui/Panel dismiss idiom) whose centered card hosts one mode view. While
// open the surface takes EXCLUSIVE keyboard focus — the compositor routes
// all input here — and releases it when closed. Opens on the focused
// output: the IPC summon carries no bar item, like PanelManager's fallback.
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

    // Dismissal is covered by Escape (Keys.onEscapePressed), the outside-click
    // MouseArea below, and item activation. There is no window-level focus
    // signal to hang an auto-close on: Quickshell's PanelWindow exposes no
    // `active` property, and the Exclusive keyboard grab (WlrKeyboardFocus above)
    // means the compositor cannot silently route focus elsewhere while open.

    // Reset the query whenever the launcher (re)opens, and take focus once
    // the surface has actually mapped (the second call is the one that
    // sticks on some compositors).
    onVisibleChanged: if (visible) {
        query.text = "";
        query.forceActiveFocus();
        focusRetry.restart();
    }

    // Outside click dismisses. Declared first so the card sits on top of it
    // (same ordering trick as Ui/Panel.qml).
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

            // The one query field, shared by every mode. Marchyo flat
            // aesthetic: bg-subtle input row with a hairline border, the
            // focused border in accent (the vicinae theme's input mapping).
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

                    // Inline autocomplete: the remaining letters of the top
                    // app match, dimmed after the cursor. Accepted by Tab, or
                    // by Right when the cursor is already at the end (the same
                    // gesture shells and browsers use). Only apps mode offers
                    // it — emoji/clipboard have no single completion.
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

    // Map-then-focus retry: on some compositors forceActiveFocus() during
    // the visible-change handler lands before the surface accepts keyboard
    // focus; one short retry after mapping covers it.
    Timer {
        id: focusRetry
        interval: 50
        onTriggered: if (root.visible)
            query.forceActiveFocus()
    }
}
