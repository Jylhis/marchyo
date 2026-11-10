import QtQuick
import QtQuick.Layouts
import qs.Commons

// The header block of a panel page: a large glyph, a title, a subtitle, and an
// optional trailing line (a value or status) on the right.
RowLayout {
    id: root

    property string iconText: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property color iconColor: Colors.accent

    Layout.fillWidth: true
    spacing: Style.panelPad

    Text {
        visible: root.iconText.length > 0
        text: root.iconText
        color: root.iconColor
        font.family: Style.fontFamily
        font.pixelSize: Math.round(Style.fontSize * 2.4)
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Colors.textHeading
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Math.round(Style.fontSize * 1.2)
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Colors.textMuted
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }
    }

    Text {
        visible: root.trailing.length > 0
        text: root.trailing
        color: Colors.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
    }
}
