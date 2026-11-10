import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// Base for a summonable panel: a full-screen transparent layer-shell overlay
// that catches the next outside click to dismiss, with a titled card under the
// top bar at the right (above a bottom bar, or centered when `centered`).
// Authors set `panelId` + `title` and pass the card's stacked contents as `body: [ ... ]`. `body` is a *named* alias, not the
// default property, so this base's own chrome (dismiss area, card) stays the
// real default children; a default alias would route them into the nested body
// container and cycle. Visibility is driven by the shared PanelManager (mutual
// exclusion): a bar widget's click calls PanelManager.toggle(panelId).
//
// Keyboard contract: a panel opened by a key or IPC takes on-demand keyboard
// focus (`keyboardFocus` is overridable; a bar click leaves it off). Escape
// closes, Down/Up move focus along the Tab chain, Tab and Shift+Tab do the
// same, and Enter or Space activate the focused control. A PointerMoveGate
// keeps hover from stealing the selection while the keyboard drives.
PanelWindow {
    id: root

    required property string panelId
    property string title: ""
    property alias body: bodyColumn.data
    // Card width; wider surfaces (the Control Center) override it.
    property int cardWidth: Style.panelWidth
    // Centered on the output instead of hanging off the bar; for large cards
    // such as the image pickers.
    property bool centered: false
    property int keyboardFocus: PanelManager.keyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    visible: PanelManager.openId === root.panelId
    // Open on the output whose bar was clicked, not Quickshell's default screen.
    // Falls back to the default for an IPC summon (no bar item). Same pattern as
    // Ui/TooltipWindow.
    screen: Screens.byName(PanelManager.screenName)
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.keyboardFocus
    // Blur anchor: modules/home/hyprland.nix registers blur layer rules for
    // the "marchyo:" namespace prefix when surfaceAlpha < 1.
    WlrLayershell.namespace: "marchyo:panel"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    function moveFocus(forward: bool): void {
        gate.hold();
        const active = keyScope.Window.activeFocusItem;
        const from = active ? active : keyScope;
        const next = from.nextItemInFocusChain(forward);
        if (next)
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    // A panel that put focus on a control of its own (Elsewhen's key catcher)
    // keeps it; otherwise the first control in the Tab chain takes it.
    function focusFirst(): void {
        const active = keyScope.Window.activeFocusItem;
        if (!active || active === keyScope)
            root.moveFocus(true);
    }

    Component.onCompleted: Dev.register("panel:" + root.panelId, root, card)

    onVisibleChanged: {
        if (!root.visible) {
            gate.release();
            return;
        }
        gate.hold();
        if (root.keyboardFocus !== WlrKeyboardFocus.None)
            Qt.callLater(root.focusFirst);
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) {
                PanelManager.close();
            } else if (e.key === Qt.Key_Down) {
                root.moveFocus(true);
            } else if (e.key === Qt.Key_Up) {
                root.moveFocus(false);
            } else {
                return;
            }
            e.accepted = true;
        }

        // Outside click dismisses. Declared first so the card sits on top of it.
        MouseArea {
            anchors.fill: parent
            onClicked: PanelManager.close()
        }

        Rectangle {
            id: card
            // Vertical placement is a plain y binding rather than three
            // conditional anchors (top / bottom / verticalCenter), which qmllint
            // rejects as a combination even though only one is ever set.
            // barMarginV is 0 in strip mode, so this reproduces the strip look.
            readonly property real barGap: Style.barMarginV + Style.barHeight + Style.panelGap
            y: root.centered ? Math.round((parent.height - card.height) / 2) : Style.barBottom ? parent.height - card.height - card.barGap : card.barGap
            anchors.right: root.centered ? undefined : parent.right
            anchors.horizontalCenter: root.centered ? parent.horizontalCenter : undefined
            anchors.rightMargin: Style.panelGap + Style.barMarginH
            width: root.cardWidth
            implicitHeight: layout.implicitHeight + Style.panelPad * 2
            radius: Style.panelRadius
            color: Qt.alpha(Colors.surface, Style.surfaceAlpha)
            border.color: Colors.border
            border.width: Style.borderWidth

            // Swallow clicks inside the card so they don't fall through to the dismiss
            // handler; interactive controls sit above this and take their own clicks.
            MouseArea {
                anchors.fill: parent
            }

            PointerMoveGate {
                id: gate
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
                        color: Colors.textHeading
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
}
