import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Commons

// On-screen toast stack: a transparent, content-sized layer-shell surface anchored
// top-right under the bar, so only the cards take clicks. A Column positioner (not a
// Layout) drives the add/move animations; there is deliberately no remove transition,
// so a dismissed toast drops immediately and the rest slide up via move.
PanelWindow {
    id: root

    visible: NotificationState.popups.length > 0
    // Follow the focused output, not Quickshell's default screen.
    screen: Screens.focused
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only while the keyboard bind has the stack selected;
    // otherwise toasts never take focus.
    WlrLayershell.keyboardFocus: NotificationState.kbActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Blur anchor: modules/home/hyprland.nix registers blur layer rules for
    // the "marchyo:" namespace prefix when surfaceAlpha < 1.
    WlrLayershell.namespace: "marchyo:notifs"

    anchors {
        top: !Style.barBottom
        bottom: Style.barBottom
        right: true
    }
    // barMarginV/H are 0 in strip mode, so this reproduces the strip look.
    margins.top: Style.barHeight + Style.barMarginV + Style.notifMargin
    margins.bottom: Style.barHeight + Style.barMarginV + Style.notifMargin
    margins.right: Style.notifMargin + Style.barMarginH

    implicitWidth: Style.notifWidth
    implicitHeight: column.implicitHeight

    Component.onCompleted: Dev.register("notifications", root, column)

    FocusScope {
        anchors.fill: parent
        focus: NotificationState.kbActive
        onFocusChanged: if (focus)
            forceActiveFocus()

        Keys.onPressed: event => {
            const digit = event.key - Qt.Key_0;
            if (event.key === Qt.Key_Escape) {
                NotificationState.stopKeyboard();
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                NotificationState.moveSelection(1);
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                NotificationState.moveSelection(-1);
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                NotificationState.dismissSelected();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                NotificationState.activateSelected();
            } else if (digit >= 1 && digit <= 9) {
                NotificationState.invokeSelectedAction(digit);
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    Column {
        id: column

        // Top/left/right (not fill) so height follows content and avoids a loop with
        // the window's implicitHeight.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.notifGap

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: Style.duration(Style.motionFast)
            }
            NumberAnimation {
                property: "y"
                from: -20
                duration: Style.duration(Style.motionFast)
                easing.type: Easing.OutQuad
            }
        }
        move: Transition {
            NumberAnimation {
                property: "y"
                duration: Style.duration(Style.motionFast)
                easing.type: Easing.OutQuad
            }
        }

        Repeater {
            model: NotificationState.decks

            NotificationDeck {
                required property var modelData
                selectedNotif: NotificationState.selectedNotification()
                width: parent.width
                deck: modelData
            }
        }
    }
}
