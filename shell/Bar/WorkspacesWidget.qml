import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/Workspaces.js" as Ws

// Hyprland workspaces for this bar's screen. Each output's bar shows only its
// own. With per-monitor workspaces (Config.perMonitorWorkspaces, from
// marchyo.workspaces.perMonitor) every monitor owns a block of ten ids
// (Services/MonitorWorkspaces) and the bar labels them 1-10. Otherwise ids are global. The first five
// slots always render, and a click creates the workspace on demand.
RowLayout {
    id: root

    // Name of the screen this bar renders on; empty = show all workspaces.
    property string screenName: ""

    // Always-present widget; `shown` is the flag Ui/BarSection reads to keep
    // the slot (it never collapses, so it stays true).
    property bool shown: true

    readonly property bool perMonitor: Config.perMonitorWorkspaces && root.screenName !== ""

    spacing: 0

    readonly property var monitor: {
        const mons = Hyprland.monitors ? Hyprland.monitors.values : [];
        for (let i = 0; i < mons.length; i++)
            if (mons[i].name === root.screenName)
                return mons[i];
        return null;
    }
    readonly property int activeId: root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
    readonly property int block: root.perMonitor ? Ws.blockFor(MonitorWorkspaces.blocks, root.screenName, root.activeId) : 0

    readonly property var workspaceList: {
        const wss = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const out = [];
        for (let i = 0; i < wss.length; i++)
            out.push({
                id: wss[i].id,
                monitor: wss[i].monitor ? wss[i].monitor.name : ""
            });
        return out;
    }

    readonly property var wsIds: {
        if (root.perMonitor)
            return Ws.workspaceIds(root.block, root.workspaceList, root.screenName, 5);
        const ids = new Set([1, 2, 3, 4, 5]);
        for (let i = 0; i < root.workspaceList.length; i++) {
            const ws = root.workspaceList[i];
            if (ws.id > 0 && (!root.screenName || ws.monitor === root.screenName))
                ids.add(ws.id);
        }
        return Array.from(ids).sort((a, b) => a - b);
    }

    function wsById(id) {
        const wss = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < wss.length; i++)
            if (wss[i].id === id)
                return wss[i];
        return null;
    }

    function own(id) {
        return !root.perMonitor || Ws.blockOf(id) === root.block;
    }

    function focus(id) {
        if (root.perMonitor && root.own(id))
            Hyprland.dispatch("marchyo.workspaces.focus(" + Ws.slotOf(id) + ", " + JSON.stringify(root.screenName) + ")");
        else
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + Number(id) + " })");
    }

    Repeater {
        model: root.wsIds

        BarItem {
            id: wsButton

            required property var modelData
            readonly property var ws: root.wsById(modelData)
            readonly property bool focused: Hyprland.focusedWorkspace && ws && Hyprland.focusedWorkspace.id === ws.id
            readonly property bool occupied: ws !== null
            readonly property string number: root.perMonitor ? Ws.label(modelData, root.block) : String(modelData)

            interactive: true
            text: occupied && !root.perMonitor ? (ws.name || number) : number
            tooltipText: root.own(modelData) ? I18n.t("workspaces.slot", number) : I18n.t("workspaces.guest", number)
            textColor: focused ? Colors.accent : (occupied ? Colors.textMuted : Colors.textFaint)
            onClicked: root.focus(modelData)
        }
    }
}
