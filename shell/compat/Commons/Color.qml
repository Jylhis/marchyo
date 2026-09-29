pragma Singleton
import QtQuick
import qs.Commons as M

// omarchy-compat `Color` singleton: the colour tokens the vendored Quattro Ui
// components and the imported omarchy plugins read, mapped onto marchyo's
// Commons/Color (which itself follows the live marchyo theme). Property writes
// on marchyo's Color propagate through these bindings, so the `accentChanged` /
// `backgroundChanged` signals the plugins connect to still fire on a theme
// switch.
QtObject {
    readonly property color accent: M.Color.accent
    readonly property color foreground: M.Color.text
    readonly property color muted: M.Color.textMuted
    readonly property color urgent: M.Color.statusErr
    readonly property color background: M.Color.bg

    readonly property QtObject popups: QtObject {
        readonly property color background: M.Color.surface
        readonly property color border: M.Color.border
    }
}
