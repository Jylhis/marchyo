import QtQuick
import qs.Commons

// A full-width action row for a panel: a leading glyph, a label, and a muted
// hint on the right. `destructive` tints it with the error colour.
ControlSurface {
    id: root

    property string iconText: ""
    property string text: ""
    property string hint: ""
    property bool destructive: false

    signal clicked

    implicitWidth: Style.panelWidth
    implicitHeight: Style.panelRowHeight
    flat: true
    hot: mouse.containsMouse
    focused: root.activeFocus
    pressed: mouse.pressed
    activeFocusOnTab: true

    readonly property color tint: root.destructive ? Colors.statusErr : Colors.text

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Style.panelPad
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconText.length > 0 ? implicitWidth : 0
        text: root.iconText
        color: root.tint
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
    }

    Text {
        anchors.left: glyph.right
        anchors.leftMargin: root.iconText.length > 0 ? Style.panelPad : 0
        anchors.right: hintText.left
        anchors.rightMargin: Style.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.tint
        elide: Text.ElideRight
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
    }

    Text {
        id: hintText
        anchors.right: parent.right
        anchors.rightMargin: Style.panelPad
        anchors.verticalCenter: parent.verticalCenter
        text: root.hint
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            root.clicked();
            e.accepted = true;
        }
    }
}
