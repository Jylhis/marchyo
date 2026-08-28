import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Commons
import qs.Bar

// Phase 1: a Jylhis-themed top bar at waybar parity, built as a simple monolith
// — shell.qml composes reusable widgets from qs.Bar (backed by qs.Ui primitives
// and the qs.Commons Color/Style singletons). No plugin registry or IPC yet;
// that architecture lands with the summonable panels of Phase 2.
ShellRoot {
  id: shell

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }
      implicitHeight: Style.barHeight
      color: Color.background

      // Three anchored sections: left and right groups, an absolutely-centered
      // clock. Simpler and more robust than fill-width spacers for centering.
      Item {
        anchors.fill: parent

        RowLayout {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing

          SessionWidget {}
          WorkspacesWidget {}
        }

        ClockWidget {
          anchors.centerIn: parent
        }

        RowLayout {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing

          TrayWidget {}
          DictationWidget {}
          CaffeineWidget {}
          DndWidget {}
          KeyboardLayoutWidget {}
          BluetoothWidget {}
          NetworkWidget {}
          AudioWidget {}
          CpuWidget {}
          PowerProfileWidget {}
          BatteryWidget {}
        }
      }
    }
  }
}
