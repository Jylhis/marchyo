import QtQuick
import qs.Commons

// A single bar segment: a horizontally-padded, vertically-centered text label
// with optional hover feedback and click/scroll signals. Every simple widget is
// a BarItem with `text` bound to a service and, if interactive, `interactive:
// true` plus the relevant signal handler.
Rectangle {
    id: root

    property alias text: label.text
    property color textColor: Color.text
    // Enables the hover highlight and pointer cursor. Set on clickable/scrollable
    // widgets; leave false for passive readouts (clock, session label).
    property bool interactive: false

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
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => (e.button === Qt.RightButton ? root.rightClicked() : root.clicked())
        onWheel: e => root.wheel(e.angleDelta.y)
    }
}
