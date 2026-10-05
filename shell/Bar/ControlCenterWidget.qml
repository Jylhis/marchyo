import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// Control Center button: opens the quick-settings panel (Panels/ControlCenter).
// Highlighted while that panel or one of its detail pages is open. The glyph is
// a code point because editing tools strip Private Use Area characters.
BarItem {
    id: root

    readonly property bool open: PanelManager.openId === "controlcenter" || PanelManager.returnId === "controlcenter"

    interactive: true
    compact: true
    text: String.fromCodePoint(0xF062E)
    textColor: root.open ? Color.accent : Color.text
    tooltipText: "Control Center"

    onClicked: PanelManager.toggle("controlcenter", root)
}
