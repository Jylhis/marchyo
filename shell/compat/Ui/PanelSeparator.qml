// Vendored from omacom/omarchy @ branch quattro (MIT), the omarchy "Quattro"
// Quickshell shell, as part of marchyo's omarchy plugin compat shim. Only the
// `qs.Ui` / `qs.Commons` imports (-> `qs.compat.*`) and `Color.` reads (->
// `CompatColor.`) are rewritten; the body is upstream.
// See shell/compat/LICENSE.omarchy and shell/compat/README.md.
import QtQuick
import qs.compat.Commons
import qs.compat.Commons as Commons

// 1px horizontal divider for panel sections. The alpha-on-foreground tint
// keeps the rule legible against the panel background without competing
// with text or borders.
Rectangle {
  id: root

  property color foreground: Commons.CompatColor.foreground
  property real strength: 0.12

  width: parent ? parent.width : implicitWidth
  implicitWidth: 100
  implicitHeight: 1
  height: 1
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, strength)
}
