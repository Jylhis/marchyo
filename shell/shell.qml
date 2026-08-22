import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.Commons

// Phase 0 spike: a single Jylhis-themed top bar with a live clock, proving the
// packaging + theming spine (quickshell package -> store QML -> autostart ->
// tokens-derived Color singleton). The plugin registry / IPC architecture lands
// in Phase 1; there is deliberately no plugin system here yet.
ShellRoot {
  id: shell

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

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
      implicitHeight: 30
      color: Color.background

      Text {
        anchors.centerIn: parent
        color: Color.foreground
        font.family: "monospace"
        font.pixelSize: 14
        text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
      }
    }
  }
}
