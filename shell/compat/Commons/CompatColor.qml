pragma Singleton
import QtQuick
import qs.Commons as M

// omarchy-compat `Color` singleton, named CompatColor because Qt 6.12's
// QtQuick `Color` singleton shadows the omarchy name (plugin reads of `Color.`
// are rewritten at bake time): the colour tokens the vendored Quattro Ui
// components and imported plugins read, mapped onto marchyo's Commons/Colors
// (which itself follows the live marchyo theme). Property writes on marchyo's
// Colors propagate through these bindings, so the `accentChanged` /
// `backgroundChanged` signals the plugins connect to still fire on a theme
// switch.
QtObject {
    readonly property color accent: M.Colors.accent
    readonly property color foreground: M.Colors.text
    readonly property color muted: M.Colors.textMuted
    readonly property color urgent: M.Colors.statusErr
    readonly property color background: M.Colors.bg

    readonly property QtObject popups: QtObject {
        readonly property color background: M.Colors.surface
        readonly property color border: M.Colors.border
    }
}
