import QtQuick
import qs.Commons

// A labelled on/off switch row. The caller owns `checked`: clicking emits
// `toggled(!checked)` and `clicked()` and leaves the property to the binding.
// Enter, Return and Space flip it while it has focus.
ControlSurface {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false

    signal clicked
    signal toggled(bool value)

    implicitWidth: Style.panelWidth
    implicitHeight: Math.max(Style.panelRowHeight, textColumn.implicitHeight + Style.panelPad)
    flat: true
    hot: mouse.containsMouse
    focused: root.activeFocus
    pressed: mouse.pressed
    activeFocusOnTab: true

    function activate(): void {
        root.toggled(!root.checked);
        root.clicked();
    }

    Column {
        id: textColumn
        anchors.left: parent.left
        anchors.leftMargin: Style.panelPad
        anchors.right: track.left
        anchors.rightMargin: Style.panelPad
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: parent.width
            text: root.label
            color: Colors.text
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        }

        Text {
            visible: root.description.length > 0
            width: parent.width
            text: root.description
            color: Colors.textMuted
            wrapMode: Text.WordWrap
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.rightMargin: Style.panelPad
        anchors.verticalCenter: parent.verticalCenter
        width: Style.panelRowHeight * 1.4
        height: Style.panelRowHeight * 0.7
        radius: height / 2
        color: root.checked ? Colors.accentSubtle : Colors.bgSubtle
        border.color: root.checked ? Colors.accent : Colors.borderStrong
        border.width: Style.borderWidth

        Rectangle {
            width: parent.height - Style.borderWidth * 4
            height: width
            radius: width / 2
            y: Style.borderWidth * 2
            x: root.checked ? parent.width - width - Style.borderWidth * 2 : Style.borderWidth * 2
            color: root.checked ? Colors.accent : Colors.textMuted

            Behavior on x {
                NumberAnimation {
                    duration: Style.duration(Style.motionFast)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            root.activate();
            e.accepted = true;
        }
    }
}
