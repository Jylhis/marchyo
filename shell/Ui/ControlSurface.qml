import QtQuick
import qs.Commons

// The painted box behind a control. It maps the control's flags to one of the
// Style.controls states (normal, hover, focus, selected, pressed), so every
// control shares the same fill, border and focus ring.
Rectangle {
    id: root

    property bool hot: false
    property bool focused: false
    property bool selected: false
    property bool pressed: false
    // Flat controls paint nothing until they leave the normal state.
    property bool flat: false

    readonly property string visualState: root.pressed ? "pressed" : root.focused ? "focus" : root.selected ? "selected" : (root.hot && Pointer.moved) ? "hover" : "normal"
    readonly property var spec: Style.control(root.visualState)
    readonly property bool bare: root.flat && root.visualState === "normal"

    radius: Style.panelRadius
    color: root.bare ? "transparent" : Qt.alpha(root.spec.fill, root.spec.fillAlpha)
    border.color: root.bare ? "transparent" : root.spec.border
    border.width: root.bare ? 0 : root.spec.borderWidth

    Behavior on color {
        ColorAnimation {
            duration: Style.duration(Style.motionFast)
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Style.duration(Style.motionFast)
        }
    }
}
