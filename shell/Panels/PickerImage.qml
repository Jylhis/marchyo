import QtQuick
import qs.Commons

Item {
    id: root

    property url source
    property bool held: true
    property int holdMs: 0
    property size decodeSize: Qt.size(480, 270)
    property bool retained: false

    onHeldChanged: {
        if (held) {
            retained = true;
            grace.stop();
        } else if (holdMs > 0) {
            grace.restart();
        } else {
            retained = false;
        }
    }
    Component.onCompleted: retained = held

    Timer {
        id: grace
        interval: root.holdMs
        onTriggered: root.retained = false
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.retained ? root.source : ""
        sourceSize: root.decodeSize
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.duration(160)
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        anchors.fill: parent
        anchors.margins: Style.spacing
        visible: image.source.toString() !== "" && image.status !== Image.Ready
        text: I18n.t(image.status === Image.Error ? "picker.loadError" : "picker.loading")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        color: image.status === Image.Error ? Colors.statusErr : Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }
}
