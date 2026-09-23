pragma Singleton
import QtQuick

// Jylhis design-token colors for the shell, delegated to Commons/Theme
// (the runtime theme reader) so every surface that binds Color.* follows a
// `marchyo theme set` live. The Nix build (packages/marchyo-shell/
// package.nix) overwrites this file with the same delegation generated from
// themes/jylhis.json; Theme's embedded fallback carries the dev/build variant.
QtObject {
    readonly property color bg: Theme.palette.bg
    readonly property color bgSubtle: Theme.palette.bgSubtle
    readonly property color surface: Theme.palette.surface
    readonly property color surfaceRaised: Theme.palette.surfaceRaised
    readonly property color text: Theme.palette.text
    readonly property color textMuted: Theme.palette.textMuted
    readonly property color textHeading: Theme.palette.textHeading
    readonly property color textFaint: Theme.palette.textFaint
    readonly property color accent: Theme.palette.accent
    readonly property color accentHover: Theme.palette.accentHover
    readonly property color accentSubtle: Theme.palette.accentSubtle
    readonly property color brand: Theme.palette.brand
    readonly property color contour: Theme.palette.contour
    readonly property color border: Theme.palette.border
    readonly property color borderStrong: Theme.palette.borderStrong
    readonly property color decorator: Theme.palette.decorator
    readonly property color selectionBg: Theme.palette.selectionBg
    readonly property color cursor: Theme.palette.cursor
    readonly property color scrim: Theme.palette.scrim
    readonly property color statusErr: Theme.palette.statusErr
    readonly property color statusWarn: Theme.palette.statusWarn
    readonly property color statusOk: Theme.palette.statusOk
    readonly property color statusInfo: Theme.palette.statusInfo

    // Back-compat aliases for the Phase 0 property names.
    readonly property color background: bg
    readonly property color foreground: text
}
