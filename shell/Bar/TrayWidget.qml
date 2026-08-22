import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Commons

// StatusNotifier system tray. Left-click activates, right-click opens the item's
// secondary action. (Waybar grouped these behind an expander; the shell shows
// them inline — grouping can come back as a later refinement.)
RowLayout {
  spacing: Style.spacing

  Repeater {
    model: SystemTray.items

    Item {
      required property var modelData
      implicitWidth: Style.fontSize + 4
      implicitHeight: Style.fontSize + 4

      IconImage {
        anchors.centerIn: parent
        implicitSize: Style.fontSize
        source: modelData.icon
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => (e.button === Qt.RightButton
          ? modelData.secondaryActivate()
          : modelData.activate())
      }
    }
  }
}
