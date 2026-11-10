import QtQuick
import qs.Commons

// A single-line text input in the shared control frame. `text` is two-way;
// `accepted()` fires on Enter, `edited()` on every user edit.
ControlSurface {
    id: root

    property alias text: input.text
    property string placeholderText: ""
    property bool password: false
    property bool readOnly: false
    readonly property alias field: input

    signal accepted
    signal edited
    signal keyPressed(var event)

    implicitWidth: Style.panelWidth
    implicitHeight: Style.panelRowHeight
    hot: hoverArea.containsMouse
    focused: input.activeFocus

    function selectAll(): void {
        input.selectAll();
    }

    function clear(): void {
        input.text = "";
    }

    function focusInput(): void {
        input.forceActiveFocus();
    }

    function blurInput(): void {
        input.focus = false;
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Style.panelPad
        anchors.rightMargin: Style.panelPad
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        readOnly: root.readOnly
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        color: Colors.text
        selectionColor: Colors.selectionBg
        selectedTextColor: Colors.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        activeFocusOnTab: true
        onAccepted: root.accepted()
        onTextEdited: root.edited()
        Keys.onPressed: e => root.keyPressed(e)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && !input.preeditText
            text: root.placeholderText
            color: Colors.textFaint
            font: input.font
        }
    }
}
