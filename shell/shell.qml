import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.Commons
import qs.Bar
import qs.Osd

// Phase 1: a Jylhis-themed top bar at waybar parity, built as a simple monolith
// — shell.qml composes reusable widgets from qs.Bar (backed by qs.Ui primitives
// and the qs.Commons Color/Style singletons). Phase 2 adds surfaces alongside it
// (starting with the OSD) as plain in-process components — no plugin registry or
// manifest system; native Quickshell service bindings and IpcHandler suffice.
ShellRoot {
  id: shell

  // On-screen display for volume/brightness/mic-mute (replaces SwayOSD). Reacts
  // natively to Pipewire and the backlight sysfs node — no external poke.
  Osd {}

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
