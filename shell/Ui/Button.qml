import QtQuick
import qs.Commons

// The basic push button: optional glyph and label, flat or bordered. Enter,
// Return and Space click it while it has focus; Tab reaches it unless
// `focusable` is off.
ControlSurface {
    id: root

    property string text: ""
    property string iconText: ""
    property bool bordered: true
    property bool focusable: true
    property bool leftAlign: false
    property color textColor: Colors.text

    signal clicked
    signal rightClicked
    signal hovered(bool isHovered)

    implicitWidth: row.implicitWidth + Style.panelPad * 2
    implicitHeight: Style.panelRowHeight
    flat: !root.bordered
    hot: mouse.containsMouse
    focused: root.activeFocus
    pressed: mouse.pressed
    opacity: root.enabled ? 1.0 : 0.5
    activeFocusOnTab: root.focusable && root.enabled

    function activate(): void {
        if (root.enabled)
            root.clicked();
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: root.leftAlign ? Style.panelPad : Math.round((parent.width - width) / 2)
        spacing: Style.spacing

        Text {
            visible: root.iconText.length > 0
            text: root.iconText
            color: root.selected ? Colors.accent : root.textColor
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            color: root.selected ? Colors.accent : root.textColor
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: e => {
            if (!root.enabled)
                return;
            e.button === Qt.RightButton ? root.rightClicked() : root.clicked();
        }
        onContainsMouseChanged: root.hovered(containsMouse)
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            root.activate();
            e.accepted = true;
        }
    }
}
