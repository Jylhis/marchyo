import QtQuick
import QtQuick.Layouts
import qs.Commons

// A small muted label with a hairline rule to its right, titling a group of
// rows in a panel.
RowLayout {
    id: root

    property string text: ""

    Layout.fillWidth: true
    Layout.topMargin: Style.spacing
    spacing: Style.spacing

    Text {
        text: root.text
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        font.bold: true
    }

    Rectangle {
        Layout.fillWidth: true
        height: Style.borderWidth
        color: Colors.border
    }
}
