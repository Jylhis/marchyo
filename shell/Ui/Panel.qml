import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// Base for a summonable panel: a full-screen transparent layer-shell overlay
// that catches the next outside click to dismiss, with a titled card under the
// top bar at the right. Authors set `panelId` + `title` and pass the card's
// stacked contents as `body: [ ... ]`. `body` is a *named* alias, not the
// default property, so this base's own chrome (dismiss area, card) stays the
// real default children; a default alias would route them into the nested body
// container and cycle. Visibility is driven by the shared PanelManager (mutual
// exclusion): a bar widget's click calls PanelManager.toggle(panelId).
PanelWindow {
    id: root

    required property string panelId
    property string title: ""
    property alias body: bodyColumn.data
    // Card width; wider surfaces (the Control Center) override it.
    property int cardWidth: Style.panelWidth

    visible: PanelManager.openId === root.panelId
    // Open on the output whose bar was clicked, not Quickshell's default screen.
    // Falls back to the default for an IPC summon (no bar item). Same pattern as
    // Ui/TooltipWindow.
    screen: Screens.byName(PanelManager.screenName)
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Blur anchor: modules/home/hyprland.nix registers blur layer rules for
    // the "marchyo:" namespace prefix when surfaceAlpha < 1.
    WlrLayershell.namespace: "marchyo:panel"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Outside click dismisses. Declared first so the card sits on top of it.
    MouseArea {
        anchors.fill: parent
        onClicked: PanelManager.close()
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.right: parent.right
        // barMarginV is 0 in strip mode, so this reproduces the strip look.
        anchors.topMargin: Style.barMarginV + Style.barHeight + Style.panelGap
        anchors.rightMargin: Style.panelGap + Style.barMarginH
        width: root.cardWidth
        implicitHeight: layout.implicitHeight + Style.panelPad * 2
        radius: Style.panelRadius
        color: Qt.alpha(Color.surface, Style.surfaceAlpha)
        border.color: Color.border
        border.width: Style.borderWidth

        // Swallow clicks inside the card so they don't fall through to the dismiss
        // handler; interactive controls sit above this and take their own clicks.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Style.panelPad
            spacing: Style.spacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing

                // Back to the panel this one was opened from as a detail page
                // (PanelManager.openDetail), e.g. the Control Center.
                PanelButton {
                    visible: PanelManager.returnId !== "" && PanelManager.openId === root.panelId
                    implicitHeight: Style.panelRowHeight * 0.8
                    text: "\u2039"
                    onClicked: PanelManager.back()
                }

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Color.textHeading
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    font.bold: true
                }
            }

            ColumnLayout {
                id: bodyColumn
                Layout.fillWidth: true
                spacing: Style.spacing
            }
        }
    }
}
