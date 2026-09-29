pragma Singleton
import QtQuick
import qs.Commons as M

// omarchy-compat `Style` singleton: the subset of omacom/omarchy@quattro's
// Commons/Style API that the vendored Quattro Ui components and the imported
// omarchy plugins read, mapped onto marchyo's own Commons/Style + Theme tokens
// so plugins pick up the active marchyo theme and font scale. Not a port of
// omarchy's scaling engine — just the surface the shim needs.
QtObject {
    id: root

    // omarchy's space(n) is a scaled pixel unit (n px at scale 1). Approximate
    // marchyo's font scale from the baked bar font size (dev default 14).
    readonly property real scale: M.Style.fontSize / 14

    function space(n) {
        return Math.round(n * root.scale);
    }
    function spaceReal(n) {
        return n * root.scale;
    }

    // Animation duration in ms, scaled by marchyo's baked animationDuration
    // (dev default 150). animationSpeed folds into that generator value.
    function duration(ms) {
        return Math.round(ms * (M.Style.animationDuration / 150));
    }

    // Subtle hover fill for a foreground colour (row highlights in plugin
    // panels). omarchy blends toward the accent; a low-alpha foreground tint is
    // close enough and theme-neutral.
    function hoverFillFor(fg, accent) {
        return Qt.rgba(fg.r, fg.g, fg.b, 0.12);
    }

    readonly property int cornerRadius: M.Style.panelRadius
    readonly property int gapsOut: M.Style.panelGap

    readonly property QtObject font: QtObject {
        readonly property string family: M.Style.fontFamily
        readonly property int caption: Math.max(1, M.Style.fontSizeSmall - 1)
        readonly property int bodySmall: M.Style.fontSizeSmall
        readonly property int body: M.Style.fontSize
        readonly property int subtitle: M.Style.fontSize + 2
        readonly property int heading: M.Style.fontSize + 6
        readonly property int title: M.Style.fontSize + 10
        readonly property int display: M.Style.fontSize + 20
    }

    readonly property QtObject bar: QtObject {
        readonly property int sizeHorizontal: M.Style.barHeight
        readonly property int iconSlot: M.Style.barHeight
        readonly property int iconCanvas: Math.round(M.Style.barHeight * 0.8)
        readonly property int iconFont: M.Style.fontSize + 2
    }

    readonly property QtObject spacing: QtObject {
        readonly property int hairline: 1
        readonly property int popupPadding: M.Style.panelPad
    }
}
