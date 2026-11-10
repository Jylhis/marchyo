import QtQuick
import QtQuick.Layouts
import qs.Commons

// The surface for popups and menus: a bordered, translucent card with an
// optional title. Children go in the content column.
Rectangle {
    id: root

    property string title: ""
    default property alias content: column.data

    implicitWidth: Style.panelWidth
    implicitHeight: layout.implicitHeight + Style.panelPad * 2
    radius: Style.panelRadius
    color: Qt.alpha(Colors.surface, Style.surfaceAlpha)
    border.color: Colors.border
    border.width: Style.borderWidth

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Style.panelPad
        spacing: Style.spacing

        Text {
            Layout.fillWidth: true
            visible: root.title.length > 0
            text: root.title
            color: Colors.textHeading
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            font.bold: true
        }

        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: Style.spacing
        }
    }
}
