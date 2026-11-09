import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// The one tooltip surface: a click-through overlay layer just below the top bar
// (above a bottom bar), centered on the hovered bar item (clamped to the
// screen). Driven by the shared Services/Tooltip singleton; every BarItem and
// tray icon writes there, and this window is instantiated once from shell.qml.
PanelWindow {
    id: root

    visible: Tooltip.active
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Blur anchor: modules/home/hyprland.nix registers blur layer rules for
    // the "marchyo:" namespace prefix when surfaceAlpha < 1.
    WlrLayershell.namespace: "marchyo:tooltip"

    // Follow the hovered item's screen; fall back to the default screen.
    readonly property var targetScreen: {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === Tooltip.screenName)
                return screens[i];
        return null;
    }
    screen: targetScreen

    anchors.top: !Style.barBottom
    anchors.bottom: Style.barBottom
    anchors.left: true
    // barMarginV is 0 in strip mode, so this reproduces the strip look.
    // Quickshell's _Window qmltypes declares Margins as an opaque stub, so qmllint cannot see its top/bottom/left/right.
    // qmllint disable missing-property
    margins.top: Style.barHeight + Style.barMarginV + 8
    margins.bottom: Style.barHeight + Style.barMarginV + 8
    // qmllint enable missing-property

    readonly property int tipX: {
        const sw = root.targetScreen ? root.targetScreen.width : 0;
        let x = Tooltip.anchorX - implicitWidth / 2;
        if (sw > 0)
            x = Math.max(0, Math.min(x, sw - implicitWidth));
        return Math.round(x);
    }
    // Quickshell's _Window qmltypes declares Margins as an opaque stub, so qmllint cannot see its top/bottom/left/right.
    // qmllint disable missing-property
    margins.left: tipX
    // qmllint enable missing-property

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Never intercept clicks: tooltips are read-only.
    mask: Region {}

    Rectangle {
        id: card
        // Opacity lives on the content item, not the window: Quickshell's
        // PanelWindow has no opacity property, so a window-level opacity
        // assignment fails to load.
        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.duration(100)
            }
        }
        radius: Style.osdRadius
        color: Qt.alpha(Colors.surface, Style.surfaceAlpha)
        border.color: Colors.border
        border.width: 1
        implicitWidth: label.implicitWidth + Style.paddingH
        implicitHeight: label.implicitHeight + Math.round(Style.spacing / 2)

        Text {
            id: label
            anchors.centerIn: parent
            text: Tooltip.text
            color: Colors.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }
    }
}
