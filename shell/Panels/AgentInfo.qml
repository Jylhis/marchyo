import QtQuick
import qs.Commons
import qs.Services

Text {
    id: root
    property string details: ""
    text: "ⓘ"
    visible: details !== ""
    color: Colors.statusWarn
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSizeSmall

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered)
                Tooltip.show(root.details, root);
            else
                Tooltip.hide(root);
        }
    }
    onDetailsChanged: {
        if (hover.hovered)
            Tooltip.show(root.details, root);
    }
    Component.onDestruction: Tooltip.hide(root)
}
