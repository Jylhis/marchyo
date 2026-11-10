import QtQuick
import qs.Commons

// One row of a popup menu: glyph, label and a muted shortcut or hint. A
// disabled row ignores input and dims. `checked` marks the current choice.
ControlSurface {
    id: root

    property string iconText: ""
    property string text: ""
    property string hint: ""
    property bool checked: false

    signal clicked

    implicitWidth: Style.panelWidth
    implicitHeight: Style.panelRowHeight
    flat: true
    hot: mouse.containsMouse
    focused: root.activeFocus
    selected: root.checked
    pressed: mouse.pressed
    opacity: root.enabled ? 1.0 : 0.5
    activeFocusOnTab: root.enabled

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Style.panelPad
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconText.length > 0 ? implicitWidth : 0
        text: root.iconText
        color: root.checked ? Colors.accent : Colors.text
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
        color: root.checked ? Colors.accent : Colors.text
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
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            root.clicked();
            e.accepted = true;
        }
    }
}
