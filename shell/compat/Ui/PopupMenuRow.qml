// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Ui` / `qs.Commons` imports (-> `qs.compat.*`) and `Color.` reads (->
// `CompatColor.`) are rewritten; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick
import qs.compat.Commons
import qs.compat.Commons as Commons

// One row of a small popup menu, like the dock's right-click menu: a label,
// a checkmark when `checked`, and `triggered()` on click. The menu owning it
// closes itself in its handler. `highlighted` lights it as hover does, for a
// menu walked with the keyboard.
Rectangle {
  id: row

  property string text: ""
  property bool checked: false
  property bool highlighted: false
  signal triggered()

  width: parent ? parent.width : 0
  height: visible ? Style.spacing.popupRowHeight : 0
  radius: Style.cornerRadius
  color: rowMouse.containsMouse || highlighted ? Style.hoverFill : "transparent"

  Text {
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.controlPaddingX
    textFormat: Text.PlainText
    text: row.text
    color: Commons.CompatColor.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
    visible: row.checked
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.controlPaddingX
    textFormat: Text.PlainText
    text: "✓"
    color: Commons.CompatColor.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.triggered()
  }
}
