import QtQuick
import qs.Commons
import qs.Services

// A single bar segment: text label with optional hover feedback, click/scroll
// signals, and a hover tooltip (via the shared Services/Tooltip singleton).
// Every simple widget is a BarItem with `text` bound to a service and, if
// interactive, `interactive: true` plus the relevant signal handler.
Rectangle {
    id: root

    // Logical visibility knob. Conditional widgets set `shown` (not `visible`)
    // so Ui/BarSection can collapse a hidden slot by reading this plain bool.
    // Binding a slot ancestor's `visible` to a loaded item's own `visible`
    // freezes that item invisible forever (the Qt Loader/visible hazard in
    // BarSection); a separate flag sidesteps it. `visible` just follows it.
    property bool shown: true
    visible: root.shown

    property alias text: label.text
    property color textColor: Color.text
    // Hover highlight + pointer cursor; leave false for passive readouts.
    property bool interactive: false
    // Glyph-only widgets take half padding so single icons don't render as
    // wide capsules next to text widgets.
    property bool compact: false
    readonly property int padH: root.compact ? Math.ceil(Style.paddingH / 2) : Style.paddingH
    // Clip + ElideRight when a layout cap makes us narrower than the text.
    property bool elide: false
    // Empty = no tooltip.
    property string tooltipText: ""

    signal clicked
    signal rightClicked
    // Mouse-wheel delta (QWheelEvent.angleDelta.y): > 0 up, < 0 down.
    signal wheel(int delta)

    implicitWidth: label.implicitWidth + root.padH * 2
    implicitHeight: Style.barHeight
    color: (root.interactive && mouse.containsMouse) ? Color.surface : "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        width: root.elide ? Math.min(implicitWidth, parent.width - root.padH * 2) : implicitWidth
        elide: root.elide ? Text.ElideRight : Text.ElideNone
        clip: root.elide
        color: root.textColor
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
            Tooltip.hide();
            e.button === Qt.RightButton ? root.rightClicked() : root.clicked();
        }
        onWheel: e => root.wheel(e.angleDelta.y)
        onContainsMouseChanged: {
            if (containsMouse && root.tooltipText.length > 0)
                hoverDelay.restart();
            else
                hoverDelay.stop();
            if (!containsMouse)
                Tooltip.hide();
        }
    }

    Timer {
        id: hoverDelay
        interval: 350
        onTriggered: Tooltip.show(root.tooltipText, root)
    }
}
