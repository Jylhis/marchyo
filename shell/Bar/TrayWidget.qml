import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Ui
import qs.Commons
import qs.Services

// StatusNotifier system tray, grouped behind a "·" expander (waybar parity): a
// click reveals or hides the icons, so the bar stays compact when the tray is
// idle. The expander only shows while there is at least one item. Left-click an
// icon activates it (or opens its menu for menu-only items); right-click opens
// the item's SNI menu when it has one (rendered by the stock QsMenuAnchor) and
// falls back to its secondary action otherwise. Hovering an icon shows its
// tooltip (title + description) through the shared tooltip surface.
RowLayout {
    id: root

    spacing: Style.spacing

    property bool expanded: false
    readonly property int itemCount: SystemTray.items ? SystemTray.items.values.length : 0

    BarItem {
        interactive: true
        visible: root.itemCount > 0
        text: "·"
        tooltipText: root.expanded ? "Hide tray icons" : "Show tray icons"
        onClicked: root.expanded = !root.expanded
    }

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem

            required property var modelData
            visible: root.expanded
            implicitWidth: root.expanded ? Style.fontSize + 4 : 0
            implicitHeight: Style.fontSize + 4

            // The item's SNI menu (DBusMenu), if it exposes one.
            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData && trayItem.modelData.hasMenu ? trayItem.modelData.menu : null
                anchor.item: trayItem
                // Pop out below the icon, right-aligned to it.
                anchor.edges: Edges.Bottom | Edges.Left
                anchor.gravity: Edges.Top | Edges.Right
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
