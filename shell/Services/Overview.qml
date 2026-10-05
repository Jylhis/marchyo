pragma Singleton
import QtQuick
import Quickshell.Hyprland
import qs.Commons
import "../Commons/Overview.js" as Ov

// Shared window-overview state: the open flag, the search query, the selected
// window, and the workspace/window model every per-monitor Overview/
// OverviewWindow renders. Seat-global, so a singleton (one query and one
// selection across monitors). The model reads Quickshell.Hyprland's toplevels,
// workspaces and monitors, and is empty while closed, so a closed overview
// costs nothing beyond the Hyprland bindings the shell already holds.
QtObject {
    id: root

    property bool open: false
    // The search field's text, mirrored here by Overview/OverviewWindow.
    property string query: ""
    // Address ("0x…") of the selected window, "" for none.
    property string selected: ""

    // Most grid columns a workspace grid uses (Commons/Overview.js gridColumns).
    readonly property int maxColumns: 5

    // Windows (Commons/Overview.js shape) plus `toplevel`, the
    // HyprlandToplevel a preview captures through.
    readonly property var windows: root.open ? root.collectWindows() : []
    readonly property var groups: root.open ? Ov.groupByWorkspace(root.windows, root.collectWorkspaces()) : []
    // Monitor id -> logical rectangle (Commons/Overview.js monitorRect).
    readonly property var monitors: root.open ? root.collectMonitors() : ({})
    // Address -> score for every window the query matches.
    readonly property var matches: Ov.filterWindows(root.windows, root.query, (t, q) => Fuzzy.score(t, q))
    // Matching addresses in display order: the keyboard navigation sequence.
    readonly property var order: Ov.navOrder(root.groups, root.matches)
    readonly property int columns: Ov.gridColumns(root.groups.length, root.maxColumns)

    function collectWindows() {
        const out = [];
        const tls = Hyprland.toplevels.values;
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            const ipc = t.lastIpcObject || {};
            // The event-driven fields (title, workspace) are fresher than the
            // last refresh's JSON; geometry only comes from the JSON.
            const raw = Object.assign({}, ipc, {
                address: t.address || ipc.address,
                title: t.title || ipc.title
            });
            if (t.workspace)
                raw.workspace = {
                    id: t.workspace.id,
                    name: t.workspace.name
                };
            const w = Ov.normalizeWindow(raw);
            if (w) {
                w.toplevel = t;
                out.push(w);
            }
        }
        return out;
    }

    function collectWorkspaces() {
        const out = [];
        const wss = Hyprland.workspaces.values;
        for (let i = 0; i < wss.length; i++)
            out.push({
                id: wss[i].id,
                name: wss[i].name,
                monitorId: wss[i].monitor ? wss[i].monitor.id : -1
            });
        return out;
    }

    function collectMonitors() {
        const out = {};
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const ipc = m.lastIpcObject || {};
            const r = Ov.monitorRect({
                id: m.id,
                name: m.name,
                x: m.x,
                y: m.y,
                width: m.width,
                height: m.height,
                scale: m.scale,
                transform: ipc.transform
            });
            if (r)
                out[r.id] = r;
        }
        return out;
    }

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    function openOverview() {
        if (root.open)
            return;
        // One overlay at a time: the launcher and panels own the same
        // full-screen click-to-dismiss idiom.
        Launcher.close();
        PanelManager.close();
        root.query = "";
        root.selected = "";
        root.refresh();
        root.open = true;
    }

    function close() {
        root.open = false;
    }

    function toggle() {
        if (root.open)
            root.close();
        else
            root.openOverview();
    }

    // Focus a window (switching to its workspace) and close.
    function activate(address) {
        if (!address)
            return;
        root.close();
        Hyprland.dispatch("focuswindow address:" + address);
    }

    function activateSelected() {
        root.activate(root.selected);
    }

    // Switch to a workspace (a click on a tile's empty area) and close.
    function goToWorkspace(id) {
        root.close();
        Hyprland.dispatch("workspace " + id);
    }

    // Keyboard navigation: `delta` windows along the order (Tab, Left/Right)
    // or one grid row (Up/Down).
    function move(delta) {
        root.selected = Ov.step(root.order, root.selected, delta);
    }

    function moveRow(delta) {
        root.selected = Ov.stepRow(root.groups, root.matches, root.selected, delta, root.columns);
    }

    function select(address) {
        root.selected = address;
    }

    function pickBest() {
        root.selected = Ov.bestMatch(root.groups, root.matches, root.query);
    }

    // Deferred so it reads the matches of the new query.
    onQueryChanged: Qt.callLater(root.pickBest)
    // A fresh model (first refresh after opening, a window closing) keeps the
    // selection when it is still a match, else picks the best one.
    onOrderChanged: if (root.order.indexOf(root.selected) < 0)
        root.pickBest()

    // Geometry ("at"/"size") only arrives with a refresh, so window and
    // workspace changes while open re-query, coalesced.
    readonly property var refreshDebounce: Timer {
        interval: 60
        onTriggered: root.refresh()
    }

    readonly property var events: Connections {
        target: Hyprland
        enabled: root.open
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "changefloatingmode":
            case "fullscreen":
            case "createworkspacev2":
            case "destroyworkspacev2":
            case "moveworkspacev2":
                root.refreshDebounce.restart();
                break;
            }
        }
    }
}
