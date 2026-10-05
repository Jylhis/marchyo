import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Services

// One window in a workspace tile: a live ScreencopyView of its toplevel,
// framed in the accent colour while selected. Exists only inside an open
// overview, so capture runs only while the overview is shown. Hidden while
// the search does not match it. Hover selects, a click focuses the window.
Item {
    id: root

    // A Services/Overview window (Commons/Overview.js shape + `toplevel`).
    required property var window
    // Position inside the tile (Commons/Overview.js windowRect).
    required property var rect

    readonly property bool selected: Overview.selected === root.window.address
    readonly property var source: root.window.toplevel && root.window.toplevel.wayland ? root.window.toplevel.wayland : null

    x: root.rect.x
    y: root.rect.y
    width: root.rect.w
    height: root.rect.h
    visible: Overview.matches[root.window.address] !== undefined
    z: root.selected ? 1 : 0

    Rectangle {
        anchors.fill: parent
        color: Color.bgSubtle
        border.width: root.selected ? 2 : Style.borderWidth
        border.color: root.selected ? Color.accent : Color.border
    }

    ScreencopyView {
        id: preview
        anchors.fill: parent
        anchors.margins: root.selected ? 2 : Style.borderWidth
        captureSource: root.source
        live: true
        constraintSize: Qt.size(root.width, root.height)
    }

    // Until the first frame arrives (or with no capture source), the class
    // names the window.
    Text {
        anchors.centerIn: parent
        width: parent.width - 2 * Style.spacing
        visible: !preview.hasContent
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.window.cls
        color: Color.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    // Title strip along the bottom edge, when the preview is tall enough.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: preview.anchors.margins
        visible: root.height > 3 * Style.fontSizeSmall
        height: title.implicitHeight + Style.spacing
        color: Qt.alpha(Color.bg, 0.8)

        Text {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.spacing
            anchors.rightMargin: Style.spacing
            elide: Text.ElideRight
            text: root.window.title
            color: root.selected ? Color.accent : Color.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: Overview.select(root.window.address)
        onClicked: Overview.activate(root.window.address)
    }
}
