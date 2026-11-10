import QtQuick
import QtQuick.Layouts
import qs.Commons

// A modal confirmation drawn over its parent: a scrim, then a card with a
// title, a message and Cancel / Confirm buttons. Set `open` to show it. Enter
// confirms, Escape cancels, and clicking the scrim cancels. `destructive`
// marks the confirm button with the error colour.
FocusScope {
    id: root

    property bool open: false
    property string title: ""
    property string message: ""
    property string confirmText: I18n.t("ui.confirm")
    property string cancelText: I18n.t("ui.cancel")
    property bool destructive: false

    signal confirmed
    signal cancelled

    anchors.fill: parent
    visible: root.open
    enabled: root.open
    z: 100

    property Item opener: null

    function confirm(): void {
        root.open = false;
        root.confirmed();
    }

    function cancel(): void {
        root.open = false;
        root.cancelled();
    }

    onOpenChanged: {
        if (root.open) {
            root.opener = root.Window.activeFocusItem;
            cancelButton.forceActiveFocus();
        } else {
            cancelButton.focus = false;
            confirmButton.focus = false;
            root.focus = false;
            if (root.opener)
                root.opener.forceActiveFocus();
            root.opener = null;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.scrim, 0.6)

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.panelPad * 2, Style.panelWidth)
        implicitHeight: content.implicitHeight + Style.panelPad * 2
        height: implicitHeight
        radius: Style.panelRadius
        color: Colors.surface
        border.color: root.destructive ? Colors.statusErr : Colors.borderStrong
        border.width: Style.borderWidth

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Style.panelPad
            spacing: Style.spacing * 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Colors.textHeading
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.message.length > 0
                text: root.message
                color: Colors.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing

                Button {
                    id: cancelButton
                    Layout.fillWidth: true
                    text: root.cancelText
                    onClicked: root.cancel()
                    KeyNavigation.tab: confirmButton
                }

                Button {
                    id: confirmButton
                    Layout.fillWidth: true
                    text: root.confirmText
                    textColor: root.destructive ? Colors.statusErr : Colors.text
                    onClicked: root.confirm()
                    KeyNavigation.tab: cancelButton
                }
            }
        }
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Escape) {
            root.cancel();
        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            // Every arrow stays inside the modal; Panel's Up/Down traversal must not see them.
            (cancelButton.activeFocus ? confirmButton : cancelButton).forceActiveFocus();
        } else {
            return;
        }
        e.accepted = true;
    }
}
