pragma Singleton
import QtQuick
import qs.Commons as M

// omarchy-compat `Style` singleton: the surface of omacom/omarchy@quattro's
// Commons/Style that the vendored Quattro Ui kit, the first-party plugins and
// imported third-party plugins read, mapped onto marchyo's own Commons/Style,
// Colors and Theme tokens so plugins follow the active Jylhis theme, font scale
// and motion switches. Not a port of omarchy's scaling engine or its
// shell.toml override layer.
QtObject {
    id: root

    readonly property int cornerRadius: M.Style.panelRadius
    readonly property int gapsOut: M.Style.panelGap

    // omarchy's space(n) is a scaled pixel unit (n px at the 12px base font).
    // marchyo bakes its scale into fontSize (14 at scale 1.0).
    readonly property real scale: M.Style.fontSize / 14

    function spaceReal(px) {
        const n = Number(px);
        if (!isFinite(n) || n <= 0)
            return 0;
        return n * root.scale;
    }

    function space(px) {
        const n = root.spaceReal(px);
        return n <= 0 ? 0 : Math.max(1, Math.round(n));
    }

    // 0 under any reduce-motion source (build flag, runtime toggle, compositor).
    function duration(ms) {
        return M.Style.duration(Number(ms) || 0);
    }

    readonly property bool reduceMotion: M.Style.reduceMotion || M.Style.motionRuntimeOff || M.Style.compositorAnimationsOff

    readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]

    // Control states. Fills, borders and widths come from marchyo's
    // Style.controls map (Jylhis tokens), not from the caller's colours:
    // omarchy tints the caller's foreground, Jylhis names the state colours.
    function _state(st) {
        if (st === "hover-cursor" || st === "hot")
            return "hover";
        return st || "normal";
    }

    function _fill(st) {
        const c = M.Style.control(root._state(st));
        return Qt.rgba(c.fill.r, c.fill.g, c.fill.b, c.fillAlpha);
    }

    function normalFillFor(fg, accent, urgent) {
        return root._fill("normal");
    }
    function hoverFillFor(fg, accent, urgent) {
        return root._fill("hover");
    }
    function selectedFillFor(fg, accent, urgent) {
        return root._fill("selected");
    }
    function pressedFillFor(fg, accent, urgent) {
        return root._fill("pressed");
    }
    function focusFillFor(fg, accent, urgent) {
        return root._fill("focus");
    }
    function selectionFillFor(fg, accent, urgent) {
        return M.Colors.selectionBg;
    }

    function controlFill(focused, hot, fg, accent) {
        if (focused)
            return root.focusFillFor(fg, accent);
        if (hot)
            return root.hoverFillFor(fg, accent);
        return root.normalFillFor(fg, accent);
    }

    function controlBorderWidth(focused, hot) {
        return M.Style.control(focused ? "focus" : (hot ? "hover" : "normal")).borderWidth;
    }

    // Text and glyph colours for a state. The caller's foreground stays the
    // text colour; the selected state takes the accent.
    function normalStateColor(fg, accent, urgent) {
        return fg || M.Colors.text;
    }
    function hoverStateColor(fg, accent, urgent) {
        return fg || M.Colors.text;
    }
    function pressedStateColor(fg, accent, urgent) {
        return fg || M.Colors.text;
    }
    function selectionStateColor(fg, accent, urgent) {
        return fg || M.Colors.text;
    }
    function selectedStateColor(fg, accent, urgent) {
        return accent || M.Colors.accent;
    }
    function focusStateColor(fg, accent, urgent) {
        return M.Colors.focusRing;
    }

    function normalBorderFor(fg, accent, urgent) {
        return M.Style.control("normal").border;
    }
    function hoverBorderFor(fg, accent, urgent) {
        return M.Style.control("hover").border;
    }
    function selectedBorderFor(fg, accent, urgent) {
        return M.Style.control("selected").border;
    }
    function focusBorderFor(fg, accent, urgent) {
        return M.Style.control("focus").border;
    }

    readonly property int normalBorderWidth: M.Style.control("normal").borderWidth
    readonly property int hoverBorderWidth: M.Style.control("hover").borderWidth
    readonly property int selectedBorderWidth: M.Style.control("selected").borderWidth
    readonly property int focusBorderWidth: M.Style.control("focus").borderWidth

    readonly property color normalFill: root._fill("normal")
    readonly property color hoverFill: root._fill("hover")
    readonly property color selectedFill: root._fill("selected")
    readonly property color pressedFill: root._fill("pressed")
    readonly property color focusFillColor: root._fill("focus")

    readonly property QtObject font: QtObject {
        readonly property string family: M.Style.fontFamily
        readonly property string resolvedFamily: M.Style.fontFamily
        readonly property string menuFamily: M.Style.fontFamily
        readonly property int baseSize: M.Style.fontSize

        // omarchy's type ramp (12px base: 10, 11, 12, 13, 14, 16, 24, 28) on
        // marchyo's body and small sizes.
        readonly property int caption: Math.max(1, M.Style.fontSizeSmall - 1)
        readonly property int bodySmall: M.Style.fontSizeSmall
        readonly property int body: M.Style.fontSize
        readonly property int subtitle: Math.round(M.Style.fontSize * 1.083)
        readonly property int title: Math.round(M.Style.fontSize * 1.167)
        readonly property int heading: Math.round(M.Style.fontSize * 1.333)
        readonly property int display: Math.round(M.Style.fontSize * 2.0)
        readonly property int displayLarge: Math.round(M.Style.fontSize * 2.333)

        readonly property int iconSmall: bodySmall
        readonly property int icon: title
        readonly property int iconLarge: Math.round(M.Style.fontSize * 1.5)
    }

    readonly property QtObject bar: QtObject {
        readonly property int sizeHorizontal: M.Style.barHeight
        readonly property int sizeVertical: M.Style.barHeight
        readonly property int iconSlot: M.Style.barHeight
        readonly property int iconCanvas: Math.round(M.Style.barHeight * 0.8)
        readonly property int iconFont: M.Style.fontSize + 2
        readonly property int iconSize: Math.min(iconCanvas, Math.round(iconFont * 0.92))
        readonly property int statusSlot: Math.round(M.Style.barHeight * 0.78)
    }

    readonly property QtObject spacing: QtObject {
        readonly property real scale: root.scale

        readonly property int hairline: Math.max(1, M.Style.borderWidth)
        readonly property int xxs: root.space(2)
        readonly property int xs: root.space(3)
        readonly property int sm: root.space(4)
        readonly property int md: root.space(6)
        readonly property int lg: root.space(8)
        readonly property int xl: root.space(10)
        readonly property int xxl: root.space(12)
        readonly property int xxxl: root.space(14)
        readonly property int huge: root.space(18)

        readonly property int controlGap: root.space(8)
        readonly property int controlPaddingX: root.space(10)
        readonly property int controlPaddingY: root.space(6)
        readonly property int inputPaddingY: root.space(7)
        readonly property int controlHeight: root.space(28)
        readonly property int popupRowHeight: M.Style.panelRowHeight
        readonly property int dropdownWidth: root.space(240)
        readonly property int searchableDropdownWidth: root.space(260)
        readonly property int numberFieldWidth: root.space(120)
        readonly property int searchablePopupMinHeight: root.space(220)
        readonly property int rowGap: root.space(8)
        readonly property int rowPaddingX: root.space(12)
        readonly property int labelGap: root.space(4)
        readonly property int panelGap: root.space(14)
        readonly property int panelPadding: root.space(18)
        readonly property int popupPadding: M.Style.panelPad
    }
}
