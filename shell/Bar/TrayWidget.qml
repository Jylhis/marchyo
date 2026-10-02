import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Ui
import qs.Commons
import qs.Services

// StatusNotifier system tray, grouped behind a "·" expander (waybar parity) so
// the bar stays compact when the tray is idle.
RowLayout {
    id: root

    spacing: Style.spacing

    property bool expanded: false
    readonly property int itemCount: SystemTray.items ? SystemTray.items.values.length : 0

    // Hide the whole widget, not just the expander, when the tray is empty:
    // a visible root with only hidden children still leaks its slot's spacing
    // (see Ui/BarSection.qml).
    visible: root.itemCount > 0

    BarItem {
        interactive: true
        compact: true
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

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData && trayItem.modelData.hasMenu ? trayItem.modelData.menu : null
                anchor.item: trayItem
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
