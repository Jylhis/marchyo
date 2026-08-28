import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Ui
import qs.Commons

// StatusNotifier system tray, grouped behind a "·" expander (waybar parity): a
// click reveals or hides the icons, so the bar stays compact when the tray is
// idle. The expander only shows while there is at least one item. Left-click an
// icon activates it, right-click runs its secondary action.
RowLayout {
  id: root

  spacing: Style.spacing

  property bool expanded: false
  readonly property int itemCount: SystemTray.items ? SystemTray.items.values.length : 0

  BarItem {
    interactive: true
    visible: root.itemCount > 0
    text: "·"
    onClicked: root.expanded = !root.expanded
  }

  Repeater {
    model: SystemTray.items

    Item {
      required property var modelData
      visible: root.expanded
      implicitWidth: root.expanded ? Style.fontSize + 4 : 0
      implicitHeight: Style.fontSize + 4

      IconImage {
        anchors.centerIn: parent
        implicitSize: Style.fontSize
        source: modelData.icon
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => (e.button === Qt.RightButton ? modelData.secondaryActivate() : modelData.activate())
      }
    }
  }
}
