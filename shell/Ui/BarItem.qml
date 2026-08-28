import QtQuick
import qs.Commons
import qs.Services

// A single bar segment: a horizontally-padded, vertically-centered text label
// with optional hover feedback, click/scroll signals, and a hover tooltip
// (rendered by the shared Ui/TooltipWindow via the Services/Tooltip singleton).
// Every simple widget is a BarItem with `text` bound to a service and, if
// interactive, `interactive: true` plus the relevant signal handler.
Rectangle {
    id: root

    property alias text: label.text
    property color textColor: Color.text
    // Enables the hover highlight and pointer cursor. Set on clickable/scrollable
    // widgets; leave false for passive readouts (clock, session label).
    property bool interactive: false
    // Tooltip text shown after a short hover; empty = no tooltip.
    property string tooltipText: ""

    signal clicked
    signal rightClicked
    // Mouse-wheel delta (QWheelEvent.angleDelta.y): > 0 up, < 0 down.
    signal wheel(int delta)

    implicitWidth: label.implicitWidth + Style.paddingH * 2
    implicitHeight: Style.barHeight
    color: (root.interactive && mouse.containsMouse) ? Color.surface : "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        color: root.textColor
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
            Tooltip.hide();
            e.button === Qt.RightButton ? root.rightClicked() : root.clicked();
        }
        onWheel: e => root.wheel(e.angleDelta.y)
        onContainsMouseChanged: {
            if (containsMouse && root.tooltipText.length > 0)
                hoverDelay.restart();
            else
                hoverDelay.stop();
            if (!containsMouse)
                Tooltip.hide();
        }
    }

    // Waybar shows tooltips on hover with a small delay; 350ms feels right.
    Timer {
        id: hoverDelay
        interval: 350
        onTriggered: Tooltip.show(root.tooltipText, root)
    }
}
