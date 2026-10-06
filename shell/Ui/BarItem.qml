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
    readonly property int padH: root.compact ? Math.ceil(Style.barItemPad / 2) : Style.barItemPad
    // Clip + ElideRight when a layout cap makes us narrower than the text.
    property bool elide: false
    // Empty = no tooltip.
    property string tooltipText: ""

    signal clicked
    signal rightClicked
    // Mouse-wheel delta (QWheelEvent.angleDelta.y): > 0 up, < 0 down.
    signal wheel(int delta)

    // The nearest enclosing Ui/BarSection when it draws the segmented style,
    // else null (flat bar, or an item outside the bar). Walked through an
    // untyped parameter: qmllint types `parent` as QQuickItem, which has no
    // `segmented`. Reading each ancestor's `parent` keeps the binding live.
    function segmentedSection(start): var {
        for (let p = start; p; p = p.parent) {
            if (p.segmentHover !== undefined)
                return p.segmented === true ? p : null;
        }
        return null;
    }
    readonly property var segmentedBar: root.segmentedSection(root.parent)
    // Hover highlight: Color.surface on the flat bar; on the segmented bar the
    // section's hover colour, which differs from both segment tones.
    readonly property color hoverColor: root.segmentedBar ? root.segmentedBar.segmentHover : Color.surface

    implicitWidth: label.implicitWidth + root.padH * 2
    implicitHeight: Style.barHeight
    color: (root.interactive && mouse.containsMouse) ? root.hoverColor : "transparent"

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
