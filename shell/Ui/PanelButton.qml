import QtQuick
import qs.Commons

// Panel-body counterpart to BarItem: the interactive pill primitive that panels
// compose from, with an optional active (selected) state.
Rectangle {
    id: root

    property alias text: label.text
    property bool active: false
    signal clicked

    implicitWidth: label.implicitWidth + Style.panelPad * 2
    implicitHeight: Style.panelRowHeight
    radius: Style.panelRadius
    color: root.active ? Color.accentSubtle : (mouse.containsMouse ? Color.surfaceRaised : Color.bgSubtle)
    border.color: root.active ? Color.accent : Color.border
    border.width: 1

    Text {
        id: label
        anchors.centerIn: parent
        color: root.active ? Color.accent : Color.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
