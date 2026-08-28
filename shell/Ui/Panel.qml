import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// Base for a summonable panel: a full-screen, transparent layer-shell overlay
// that catches the next outside click to dismiss, with a titled card anchored
// under the top bar at the right. Panel authors set `panelId` + `title` and pass
// the card's stacked contents as `body: [ ... ]`. `body` is a *named* alias, not
// the default property, so this base's own chrome (dismiss area, card) stays the
// real default children — a default alias would route them into the nested body
// container and cycle. Non-visual helpers a panel declares (service trackers,
// polls) likewise stay ordinary children. Visibility is driven entirely by the
// shared PanelManager (mutual exclusion): a bar widget's click calls
// PanelManager.toggle(panelId).
PanelWindow {
  id: root

  required property string panelId
  property string title: ""
  property alias body: bodyColumn.data

  visible: PanelManager.openId === root.panelId
  color: "transparent"
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  // Outside click dismisses. Declared first so the card sits on top of it.
  MouseArea {
    anchors.fill: parent
    onClicked: PanelManager.close()
  }

  Rectangle {
    id: card
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: Style.barHeight + Style.panelGap
    anchors.rightMargin: Style.panelGap
    width: Style.panelWidth
    implicitHeight: layout.implicitHeight + Style.panelPad * 2
    radius: Style.panelRadius
    color: Color.surface
    border.color: Color.border
    border.width: 1

    // Swallow clicks inside the card so they don't fall through to the dismiss
    // handler; interactive controls sit above this and take their own clicks.
    MouseArea {
      anchors.fill: parent
    }

    ColumnLayout {
      id: layout
      anchors.fill: parent
      anchors.margins: Style.panelPad
      spacing: Style.spacing

      Text {
        Layout.fillWidth: true
        text: root.title
        color: Color.textHeading
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        font.bold: true
      }

      ColumnLayout {
        id: bodyColumn
        Layout.fillWidth: true
        spacing: Style.spacing
      }
    }
  }
}
