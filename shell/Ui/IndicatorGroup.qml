import QtQuick
import qs.Commons
import "../Commons/IndicatorLayout.js" as IndicatorLayout

Item {
    id: root

    property var entries: []
    property var resolve: null
    property var configure: null
    property bool indicatorsRevealed: false
    property bool fixedRight: false
    property var activeOrder: []
    readonly property bool shown: root.implicitWidth > 0

    function widgetState(widget): var {
        if (!widget)
            return {
                shown: false,
                active: false
            };
        return {
            shown: widget.shown === true,
            active: widget.indicatorActive !== undefined ? widget.indicatorActive : widget.shown
        };
    }

    function cellWidth(cell): real {
        return cell ? cell.slotWidth : 0;
    }

    function desiredWidth(widget): real {
        return widget && widget.shown ? widget.implicitWidth : 0;
    }

    readonly property var activeFlags: {
        const active = [];
        for (let i = 0; i < items.count; i++) {
            const cell = items.itemAt(i);
            const state = root.widgetState(cell ? cell.item : null);
            active.push(state.active);
        }
        return active;
    }
    onActiveFlagsChanged: {
        root.activeOrder = IndicatorLayout.activeOrder(root.activeOrder, root.activeFlags);
    }

    readonly property var geometry: {
        const widths = [];
        for (let i = 0; i < items.count; i++) {
            const cell = items.itemAt(i);
            widths.push(root.cellWidth(cell));
        }
        const flags = root.activeFlags;
        return IndicatorLayout.positions(widths, flags, root.fixedRight, root.activeOrder);
    }

    implicitWidth: root.geometry.total
    implicitHeight: Style.barHeight

    Repeater {
        id: items
        model: root.entries
        Loader {
            required property var modelData
            required property int index
            property real slotWidth: root.desiredWidth(item)
            Behavior on slotWidth {
                NumberAnimation {
                    duration: Style.duration(140)
                    easing.type: Easing.OutCubic
                }
            }
            x: root.geometry.offsets[index] || 0
            width: slotWidth
            height: root.height
            clip: true
            sourceComponent: root.resolve ? root.resolve(modelData.id) : null
            onLoaded: {
                if (root.configure)
                    root.configure(item, modelData);
            }
        }
    }
}
