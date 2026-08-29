import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// The one tooltip surface: a click-through overlay layer anchored just below
// the top bar, centered under the hovered bar item (clamped to the screen).
// Driven entirely by the shared Services/Tooltip singleton — every BarItem and
// tray icon writes there; this window is instantiated once from shell.qml.
PanelWindow {
    id: root

    visible: Tooltip.active
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Follow the hovered item's screen; fall back to the default screen.
    readonly property var targetScreen: {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === Tooltip.screenName)
                return screens[i];
        return null;
    }
    screen: targetScreen

    anchors.top: true
    anchors.left: true
    margins.top: Style.barHeight + 8

    readonly property int tipX: {
        const sw = root.targetScreen ? root.targetScreen.width : 0;
        let x = Tooltip.anchorX - implicitWidth / 2;
        if (sw > 0)
            x = Math.max(0, Math.min(x, sw - implicitWidth));
        return Math.round(x);
    }
    margins.left: tipX

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Never intercept clicks — tooltips are read-only.
    mask: Region {}

    Rectangle {
        id: card
        // Fade the card in when the tooltip shows. Opacity lives on the content
        // item, not the window: Quickshell's PanelWindow has no opacity property
        // (anchors/margins/exclusiveZone/color/mask only), so a window-level
        // opacity assignment fails to load.
        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
        radius: Style.osdRadius
        color: Color.surface
        border.color: Color.border
        border.width: 1
        implicitWidth: label.implicitWidth + Style.paddingH
        implicitHeight: label.implicitHeight + Math.round(Style.spacing / 2)

        Text {
            id: label
            anchors.centerIn: parent
            text: Tooltip.text
            color: Color.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }
    }
}
