import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Ui
import qs.Commons

// Hyprland workspaces. Click switches; the focused workspace is accented.
RowLayout {
  spacing: 0

  Repeater {
    model: Hyprland.workspaces

    BarItem {
      required property var modelData
      interactive: true
      text: modelData.name
      textColor: (Hyprland.focusedWorkspace && modelData.id === Hyprland.focusedWorkspace.id)
        ? Color.accent
        : Color.textMuted
      onClicked: Hyprland.dispatch("workspace " + modelData.id)
    }
  }
}
