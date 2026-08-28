pragma Singleton
import QtQuick

// Jylhis design-token colors for the shell. These checked-in values are the
// Field (dark) variant so `quickshell -p shell` runs standalone during dev.
// The Nix build (packages/marchyo-shell/package.nix) overwrites this file with
// the values for the host's marchyo.theme.variant, generated from tokens.json.
// Keep this in sync with the token set the generator emits (palette + status).
QtObject {
    readonly property color bg: "#0d0f14"
    readonly property color bgSubtle: "#14171e"
    readonly property color surface: "#1b1f28"
    readonly property color surfaceRaised: "#232833"
    readonly property color text: "#d6dae2"
    readonly property color textMuted: "#9aa0ab"
    readonly property color textHeading: "#f2f4f8"
    readonly property color textFaint: "#656b76"
    readonly property color accent: "#e0a33a"
    readonly property color accentHover: "#f0b95c"
    readonly property color accentSubtle: "#262119"
    readonly property color brand: "#ef8a4a"
    readonly property color contour: "#6f9be0"
    readonly property color border: "#2b303b"
    readonly property color borderStrong: "#3a4150"
    readonly property color decorator: "#39415a"
    readonly property color selectionBg: "#3a2f1c"
    readonly property color cursor: "#e0a33a"
    readonly property color scrim: "#05060a"
    readonly property color statusErr: "#f0685f"
    readonly property color statusWarn: "#d9b34a"
    readonly property color statusOk: "#6bbf6b"
    readonly property color statusInfo: "#5fb8cf"

    // Back-compat aliases for the Phase 0 property names.
    readonly property color background: bg
    readonly property color foreground: text
}
