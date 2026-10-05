import QtQuick
import qs.Commons

// Panel-body horizontal slider over a 0..1 value. Stateless: `value` is bound
// by the caller and `moved(v)` reports the clicked/dragged/scrolled position,
// which the caller writes back to its service. `dimmed` greys the fill (e.g.
// a muted sink) without disabling input.
Item {
    id: root

    property real value: 0
    property bool dimmed: false
    // Wheel step as a fraction of the range.
    property real step: 0.05
    signal moved(real value)

    readonly property real shown: Math.max(0, Math.min(1, root.value))

    implicitWidth: Style.panelWidth
    implicitHeight: Style.panelRowHeight

    function clamp(v: real): real {
        return Math.max(0, Math.min(1, v));
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Style.sliderTrackHeight
        radius: height / 2
        color: Color.bgSubtle
        border.color: Color.border
        border.width: 1

        Rectangle {
            width: track.width * root.shown
            height: track.height
            radius: track.radius
            color: root.dimmed ? Color.textFaint : Color.accent
        }
    }

    Rectangle {
        width: Style.sliderTrackHeight * 2.5
        height: width
        radius: width / 2
        x: (root.width - width) * root.shown
        anchors.verticalCenter: parent.verticalCenter
        color: root.dimmed ? Color.textFaint : Color.accent
        border.color: Color.surface
        border.width: Style.borderWidth
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: e => root.moved(root.clamp(e.x / root.width))
        onPositionChanged: e => {
            if (pressed)
                root.moved(root.clamp(e.x / root.width));
        }
        onWheel: e => root.moved(root.clamp(root.value + (e.angleDelta.y > 0 ? root.step : -root.step)))
    }
}
