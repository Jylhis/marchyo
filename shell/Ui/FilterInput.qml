import QtQuick
import qs.Commons

// A search box for lists with a clear button. It forwards Up, Down and Enter
// as signals instead of consuming them, so a list below can follow the
// selection while the caret stays in the field. Escape clears a non-empty
// filter; on an empty one it passes through so the panel can close.
TextField {
    id: root

    signal moveUp
    signal moveDown
    signal submitted
    signal cleared

    placeholderText: I18n.t("ui.filter")

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Style.panelPad
        anchors.verticalCenter: parent.verticalCenter
        visible: root.text.length > 0
        text: "×"
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Style.spacing
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.clear();
                root.cleared();
            }
        }
    }

    onKeyPressed: e => {
        if (e.key === Qt.Key_Down) {
            root.moveDown();
        } else if (e.key === Qt.Key_Up) {
            root.moveUp();
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            root.submitted();
        } else if (e.key === Qt.Key_Escape && root.text.length > 0) {
            root.clear();
            root.cleared();
        } else {
            return;
        }
        e.accepted = true;
    }
}
