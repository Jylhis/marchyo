import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Commons

// The on-screen toast stack: a transparent layer-shell surface anchored top-right
// under the bar, rendering NotificationState.popups newest-first. Sized to its
// content so only the cards take clicks (the rest of the screen stays free), and
// only materialised while there is something to show.
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

    ColumnLayout {
        id: column

        // Top/left/right anchors (not fill) so height stays driven by the content,
        // avoiding a loop with the window's implicitHeight.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.notifGap

        Repeater {
            model: NotificationState.popups

            NotificationPopup {
                required property var modelData
                Layout.fillWidth: true
                notif: modelData
            }
        }
    }
}
