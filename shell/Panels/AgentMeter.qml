import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import "../Commons/AgentUsage.js" as AgentUsage

RowLayout {
    id: root
    required property var limit
    property real fetchedAt: 0
    Layout.fillWidth: true
    spacing: Style.spacing

    readonly property string tooltipText: root.fetchedAt > 0 ? I18n.t("agents.meterTooltip", Math.round(root.limit.percent * 100), AgentUsage.ageMinutes(root.fetchedAt, Agents.now)) : I18n.t("agents.meterUnchecked", Math.round(root.limit.percent * 100))

    Text {
        Layout.preferredWidth: Style.fontSizeSmall * 7
        text: root.limit.label
        elide: Text.ElideRight
        color: Colors.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.sliderTrackHeight
        radius: height / 2
        color: Colors.bgSubtle
        Rectangle {
            width: parent.width * root.limit.percent
            height: parent.height
            radius: parent.radius
            color: Agents.levelColor(root.limit.percent)
            Behavior on width {
                NumberAnimation {
                    duration: Style.duration(160)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Text {
        Layout.preferredWidth: Style.fontSizeSmall * 7
        horizontalAlignment: Text.AlignRight
        text: Agents.resetClock(root.limit.resetsAt)
        color: Colors.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered)
                Tooltip.show(root.tooltipText, root);
            else
                Tooltip.hide(root);
        }
    }
    onTooltipTextChanged: {
        if (hover.hovered)
            Tooltip.show(root.tooltipText, root);
    }
    Component.onDestruction: Tooltip.hide(root)
}
