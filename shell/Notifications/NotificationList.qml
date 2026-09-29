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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }
    margins.top: Style.barHeight + Style.notifMargin
    margins.right: Style.notifMargin

    implicitWidth: Style.notifWidth
    implicitHeight: column.implicitHeight

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
                duration: Style.animationDuration
            }
            NumberAnimation {
                property: "y"
                from: -20
                duration: Style.animationDuration
                easing.type: Easing.OutQuad
            }
        }
        move: Transition {
            NumberAnimation {
                property: "y"
                duration: Style.animationDuration
                easing.type: Easing.OutQuad
            }
        }

        Repeater {
            model: NotificationState.popups

            NotificationPopup {
                required property var modelData
                width: parent.width
                notif: modelData
            }
        }
    }
}
