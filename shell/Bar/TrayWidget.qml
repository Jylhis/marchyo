import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Ui
import qs.Commons
import qs.Services

// StatusNotifier system tray. Items listed in the entry's `settings.pinned`
// (an SNI id or title) always show; every other item folds into a drawer behind
// a "·" expander, so the bar stays compact when the tray is idle. With no
// pinned items the whole tray is the drawer.
RowLayout {
    id: root

    spacing: Style.space("xs")

    // Per-entry layout settings (applyWidget): { pinned: [id or title, ...] }.
    property var settings: ({})
    readonly property var pinned: Array.isArray(root.settings.pinned) ? root.settings.pinned : []

    property bool expanded: false
    readonly property int itemCount: SystemTray.items ? SystemTray.items.values.length : 0
    readonly property int foldedCount: {
        let n = 0;
        const items = SystemTray.items ? SystemTray.items.values : [];
        for (let i = 0; i < items.length; i++)
            if (!root.isPinned(items[i]))
                n++;
        return n;
    }

    function isPinned(item): bool {
        return item && (root.pinned.indexOf(item.id) >= 0 || root.pinned.indexOf(item.title) >= 0);
    }

    // Hide the whole widget, not just the expander, when the tray is empty:
    // a visible root with only hidden children still leaks its slot's spacing
    // (see Ui/BarSection.qml). `shown` is the slot-collapse flag BarSection
    // reads; `visible` follows it (this is not a BarItem, so both are declared
    // here).
    property bool shown: root.itemCount > 0
    visible: root.shown

    BarItem {
        interactive: true
        compact: true
        visible: root.foldedCount > 0
        text: "·"
        tooltipText: I18n.t(root.expanded ? "tray.hide" : "tray.show")
        onClicked: root.expanded = !root.expanded
    }

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem

            required property var modelData
            readonly property bool open: root.expanded || root.isPinned(modelData)
            visible: open
            implicitWidth: open ? Style.fontSize + Style.space("xs") : 0
            implicitHeight: Style.fontSize + Style.space("xs")

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData && trayItem.modelData.hasMenu ? trayItem.modelData.menu : null
                anchor.item: trayItem
                anchor.edges: (Style.barBottom ? Edges.Top : Edges.Bottom) | Edges.Left
                anchor.gravity: (Style.barBottom ? Edges.Bottom : Edges.Top) | Edges.Right
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Style.fontSize
                source: trayItem.modelData.icon
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => {
                    Tooltip.hide();
                    if (e.button === Qt.RightButton) {
                        if (trayItem.modelData.hasMenu)
                            menuAnchor.open();
                        else
                            trayItem.modelData.secondaryActivate();
                    } else if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                        // Menu-only items have no activate/secondary actions.
                        menuAnchor.open();
                    } else {
                        trayItem.modelData.activate();
                    }
                }
                onContainsMouseChanged: {
                    if (containsMouse) {
                        const t = trayItem.modelData;
                        const tip = [t.tooltipTitle, t.tooltipDescription].filter(s => s && s.length > 0).join("\n");
                        if (tip.length > 0)
                            Tooltip.show(tip, trayItem);
                    } else {
                        Tooltip.hide();
                    }
                }
            }
        }
    }
}
