import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Ui
import qs.Commons

// Hyprland workspaces for this bar's screen (waybar parity: workspaces are
// per-monitor, so each output's bar shows only its own). The first five
// workspaces are persistent (mirroring waybar's persistent-workspaces 1–5):
// they render even when they don't exist yet, and a click dispatches to them
// (Hyprland creates the workspace on demand). Click switches; the focused
// workspace is accented.
RowLayout {
    id: root

    // Name of the screen this bar renders on; empty = show all workspaces.
    property string screenName: ""

    spacing: 0

    // Union of the persistent ids (1–5) and every workspace on this monitor,
    // sorted. Entries carry the live workspace object when it exists, else null.
    readonly property var wsIds: {
        const ids = new Set([1, 2, 3, 4, 5]);
        const wss = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < wss.length; i++) {
            const ws = wss[i];
            if (!screenName || (ws.monitor && ws.monitor.name === screenName))
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

    Repeater {
        model: root.wsIds

        BarItem {
            id: wsButton

            required property var modelData
            readonly property var ws: root.wsById(modelData)
            readonly property bool focused: Hyprland.focusedWorkspace && ws && Hyprland.focusedWorkspace.id === ws.id
            readonly property bool occupied: ws !== null

            interactive: true
            text: occupied ? (ws.name || String(modelData)) : String(modelData)
            textColor: focused ? Color.accent : (occupied ? Color.textMuted : Color.textFaint)
            onClicked: Hyprland.dispatch("workspace " + modelData)
        }
    }
}
