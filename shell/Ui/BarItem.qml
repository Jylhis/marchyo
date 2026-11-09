import QtQuick
import qs.Commons
import qs.Services
import "../Commons/Appearance.js" as Appearance

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
    // The heading ink once the bar body is see-through, so a label stays
    // readable over a wallpaper (Appearance.barTextRole).
    property color textColor: Appearance.barTextRole(Style.barAlpha) === "textHeading" ? Colors.textHeading : Colors.text
    // Hover highlight + pointer cursor; leave false for passive readouts.
    property bool interactive: false
    // Glyph-only widgets take half padding so single icons don't render as
    // wide capsules next to text widgets.
    property bool compact: false
    readonly property int padH: root.compact ? Math.ceil(Style.barItemPad / 2) : Style.barItemPad
    // Clip + ElideRight when a layout cap makes us narrower than the text.
    property bool elide: false
    // Widest text the label can show (e.g. "󰁹 100"). When set, the item keeps
    // that width and left-aligns the label, so a changing digit count neither
    // resizes the item nor moves its glyph or neighbours.
    property string reserveText: ""
    // Empty = no tooltip.
    property string tooltipText: ""

    signal clicked
    signal rightClicked
    signal middleClicked
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
    // Hover highlight: Colors.surface on the flat bar; on the segmented bar the
    // section's hover colour, which differs from both segment tones.
    readonly property color hoverColor: root.segmentedBar ? root.segmentedBar.segmentHover : Colors.surface

    implicitWidth: {
        if (root.compact && Array.from(root.text).length === 1 && root.reserveText.length === 0)
            return Style.fontSize + 10;
        const reservedWidth = root.reserveText.length > 0 ? reserve.advanceWidth : 0;
        const textWidth = Math.max(label.implicitWidth, reservedWidth);
        return Math.max(root.compact ? Style.fontSize + 10 : 0, textWidth + root.padH * 2);
    }
    implicitHeight: Style.barHeight
    readonly property bool hovered: root.interactive && mouse.containsMouse
    readonly property bool tooltipHovered: mouse.containsMouse
    color: root.hovered ? root.hoverColor : "transparent"
    // Hover draws the control-state hairline; keyboard focus (Tab, then
    // Return or Space to activate) draws the 2 px focus ring.
    border.width: root.hovered ? Style.borderWidth : 0
    border.color: Style.control("hover").border
    radius: Style.space("2xs")
    activeFocusOnTab: root.interactive
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    onVisibleChanged: {
        if (!visible) {
            hoverDelay.stop();
            Tooltip.hide(root);
        }
    }
    onShownChanged: {
        if (!shown) {
            hoverDelay.stop();
            Tooltip.hide(root);
        }
    }
    Component.onDestruction: Tooltip.hide(root)

    Behavior on color {
        ColorAnimation {
            duration: Style.duration(160)
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Style.duration(140)
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.activeFocus
        color: "transparent"
        radius: root.radius
        border.width: Style.borderFocus
        border.color: Style.control("focus").border
    }

    TextMetrics {
        id: reserve
        font: label.font
        text: root.reserveText
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: root.reserveText.length > 0 ? root.padH : Math.round((parent.width - width) / 2)
        width: root.elide ? Math.min(implicitWidth, parent.width - root.padH * 2) : implicitWidth
        elide: root.elide ? Text.ElideRight : Text.ElideNone
        clip: root.elide
        color: root.textColor
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        scale: root.interactive && mouse.pressed ? 0.9 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Style.duration(160)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Style.duration(160)
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => {
            hoverDelay.stop();
            Tooltip.hide();
            if (e.button === Qt.MiddleButton)
                root.middleClicked();
            else if (e.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onWheel: e => root.wheel(e.angleDelta.y)
        onContainsMouseChanged: {
            if (containsMouse && root.tooltipText.length > 0) {
                if (Tooltip.warm)
                    Tooltip.show(root.tooltipText, root);
                else
                    hoverDelay.restart();
            } else
                hoverDelay.stop();
            if (!containsMouse)
                Tooltip.hide(root);
        }
    }

    Timer {
        id: hoverDelay
        interval: 350
        onTriggered: {
            if (root.visible && mouse.containsMouse)
                Tooltip.show(root.tooltipText, root);
        }
    }
}
