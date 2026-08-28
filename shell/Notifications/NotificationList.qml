import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Commons

// The on-screen toast stack: a transparent layer-shell surface anchored top-right
// under the bar, rendering NotificationState.popups newest-first. Sized to its
// content so only the cards take clicks (the rest of the screen stays free), and
// only materialised while there is something to show. A Column (positioner, not
// a layout) so the toasts animate in/out: fade+slide on add, fade on remove, and
// the stack smoothly reshuffles on displace — mako's toast feel.
PanelWindow {
    id: root

    visible: NotificationState.popups.length > 0
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

        // Top/left/right anchors (not fill) so height stays driven by the content,
        // avoiding a loop with the window's implicitHeight.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.notifGap

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
            }
            NumberAnimation {
                property: "y"
                from: -20
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 150
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 150
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
