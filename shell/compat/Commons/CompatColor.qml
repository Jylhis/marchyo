pragma Singleton
import QtQuick
import qs.Commons as M

// omarchy-compat `Color` singleton, exported as `CompatColor` because Qt 6.12's
// QtQuick `Color` singleton shadows any other bare `Color` (see ../README.md).
// omarchy's surface roles are mapped onto marchyo's Commons/Colors (Jylhis
// tokens, which follow the live theme); no colour values are defined here.
// Property writes on marchyo's Colors propagate through these bindings, so the
// `accentChanged` / `backgroundChanged` signals plugins connect to still fire
// on a theme switch.
QtObject {
    readonly property color accent: M.Colors.accent
    readonly property color foreground: M.Colors.text
    readonly property color muted: M.Colors.textMuted
    readonly property color urgent: M.Colors.statusErr
    readonly property color background: M.Colors.bg

    readonly property QtObject bar: QtObject {
        readonly property color background: M.Colors.bg
        readonly property color text: M.Colors.text
        readonly property color active: M.Colors.statusErr
    }

    readonly property QtObject popups: QtObject {
        readonly property color background: M.Colors.surface
        readonly property color text: M.Colors.text
        readonly property color border: M.Colors.border
    }

    readonly property QtObject tooltip: QtObject {
        readonly property color background: M.Colors.surfaceRaised
        readonly property color text: M.Colors.text
        readonly property color border: M.Colors.borderStrong
    }

    readonly property QtObject notifications: QtObject {
        readonly property color background: M.Colors.surface
        readonly property color text: M.Colors.text
        readonly property color border: M.Colors.border
        readonly property color countdown: M.Colors.accent
    }

    readonly property QtObject menu: QtObject {
        readonly property color background: M.Colors.surface
        readonly property color text: M.Colors.text
        readonly property color border: M.Colors.border
        readonly property color scrim: Qt.rgba(M.Colors.scrim.r, M.Colors.scrim.g, M.Colors.scrim.b, 0.5)
        readonly property color selectedBackground: M.Colors.accentSubtle
        readonly property color selectedText: M.Colors.accent
        readonly property color selectedBorder: "transparent"
    }

    readonly property QtObject polkit: QtObject {
        readonly property color background: M.Colors.surface
        readonly property color text: M.Colors.text
        readonly property color textError: M.Colors.statusErr
        readonly property color border: M.Colors.border
        readonly property color borderError: M.Colors.statusErr
        readonly property color accent: M.Colors.accent
        readonly property color scrim: Qt.rgba(M.Colors.scrim.r, M.Colors.scrim.g, M.Colors.scrim.b, 0.5)
    }

    readonly property QtObject lock: QtObject {
        readonly property color background: Qt.rgba(M.Colors.bg.r, M.Colors.bg.g, M.Colors.bg.b, 0.8)
        readonly property color text: M.Colors.text
        readonly property color placeholder: M.Colors.textFaint
        readonly property color textError: M.Colors.statusErr
        readonly property color border: M.Colors.border
        readonly property color borderActive: M.Colors.accent
        readonly property color borderError: M.Colors.statusErr
        readonly property color selection: M.Colors.selectionBg
    }

    readonly property QtObject imagePicker: QtObject {
        readonly property color text: M.Colors.text
        readonly property color selectedBorder: M.Colors.accent
        readonly property color unselectedBorder: M.Colors.borderStrong
    }
}
